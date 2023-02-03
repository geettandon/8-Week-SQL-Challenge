-- 8 WEEK SQL CHALLENGE: WEEK 1. The relevant details about the case study can be found
-- on this link: https://8weeksqlchallenge.com/case-study-1/


/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- Quering sales table
SELECT *
FROM sales;

-- Quering menu table
SELECT *
FROM menu;

-- Quering members table
SELECT *
FROM members;

-- Total amount spent by each customer at the restaurant
SELECT S.customer_id,
		SUM(M.price) AS total_amount_spent
FROM dannys_diner.dbo.sales AS S
INNER JOIN dannys_diner.dbo.menu AS M
ON S.product_id = M.product_id
GROUP BY S.customer_id
ORDER BY total_amount_spent DESC;

-- Days each customer visited the restaurant
SELECT customer_id,
		COUNT(DISTINCT(order_date)) AS number_days_visited
FROM dannys_diner.dbo.sales
GROUP BY customer_id
ORDER BY number_days_visited DESC;

-- First item from the menu purchased by each customer
SELECT DISTINCT(S.customer_id),
		M.product_id,
        M.product_name
FROM (
	SELECT *,
		RANK() OVER(PARTITION BY customer_id ORDER BY order_date ASC) AS rank
  	FROM dannys_diner.dbo.sales
    ) AS S
INNER JOIN dannys_diner.dbo.menu AS M
ON S.product_id = M.product_id
WHERE rank = 1;

-- Most purchased item on the menu
SELECT TOP 1 product_id, 
			COUNT(product_id) AS num_times_purchased
FROM dannys_diner.dbo.sales
GROUP BY product_id
ORDER BY COUNT(product_id) DESC;

-- Number of times the most purchased item was purchased by customers
WITH Most_purchased AS (
  	SELECT customer_id,
		MIN(product_id) AS product_id,
		COUNT(product_id) AS times_purchased
	FROM dannys_diner.dbo.sales
	WHERE product_id IN (
                SELECT TOP 1 product_id
                FROM dannys_diner.dbo.sales
                GROUP BY product_id
                ORDER BY COUNT(product_id) DESC
                )
	GROUP BY customer_id
		)
        
SELECT MP.customer_id,
		MP.product_id AS most_purchased_product_id,
		M.product_name AS most_purchased_product_name,
        MP.times_purchased
FROM Most_Purchased AS MP
INNER JOIN dannys_diner.dbo.menu AS M
ON MP.product_id = M.product_id
ORDER BY MP.customer_id ASC;

-- Most popular item for each customer
WITH Popular_item AS (
        SELECT customer_id,
              product_id,
              times_purchased,
              DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY times_purchased DESC) AS rank
      FROM (SELECT customer_id,
                  product_id,
                  COUNT(product_id) AS times_purchased
            FROM dannys_diner.dbo.sales
            GROUP BY customer_id, product_id
     		) AS S
			)
            
SELECT P.customer_id, 
		P.product_id AS popular_item_id,
        M.product_name AS popular_item_name
FROM Popular_item AS P
INNER JOIN dannys_diner.dbo.menu AS M
ON P.product_id = M.product_id
WHERE Rank = 1
ORDER BY P.customer_id;

-- Item purchased first by the customer after they became a member
WITH item_after_member AS (
  	SELECT s.customer_id,
            s.order_date,
            s.product_id,
            m.join_date,
            DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rank
    FROM dannys_diner.dbo.sales AS S
    LEFT JOIN dannys_diner.dbo.members AS M
    ON S.customer_id = M.customer_id AND S.order_date >= M.join_date
    WHERE m.join_date IS NOT NULL
		)
       
SELECT AM.customer_id,
		AM.product_id,
        MN.product_name
FROM item_after_member AS AM
INNER JOIN dannys_diner.dbo.menu AS MN
ON AM.product_id = MN.product_id
WHERE rank = 1
ORDER BY AM.customer_id;

-- Item purchased just before the customer became a member
WITH item_before_member AS (
  	SELECT s.customer_id,
            s.order_date,
            s.product_id,
            m.join_date,
            DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rank
    FROM dannys_diner.dbo.sales AS S
    LEFT JOIN dannys_diner.dbo.members AS M
    ON S.customer_id = M.customer_id AND S.order_date < M.join_date
    WHERE m.join_date IS NOT NULL
		)
     
SELECT BM.customer_id,
		BM.product_id,
        MN.product_name
FROM item_before_member AS BM
INNER JOIN dannys_diner.dbo.menu AS MN
ON BM.product_id = MN.product_id
WHERE rank = 1
ORDER BY BM.customer_id;

-- The total items and amount spent for each member before they became a member
SELECT S.customer_id,
		COUNT(S.product_id) AS total_items_purchased,
        SUM(MN.price) AS total_amount_spent
FROM dannys_diner.dbo.sales AS S
LEFT JOIN dannys_diner.dbo.members AS M
ON S.customer_id = M.customer_id
	AND S.order_date < M.join_date
LEFT JOIN dannys_diner.dbo.menu AS MN
ON S.product_id = MN.product_id
WHERE m.join_date IS NOT NULL
GROUP BY S.customer_id
ORDER BY S.customer_id;

-- Scenario: Each $1 spent equates to 10 points and sushi has a 2x points multiplier.
-- Calculating points each customer would have earned
SELECT S.customer_id,
        SUM(CASE
        		WHEN M.product_name = 'sushi' THEN M.price * 20
           		ELSE M.price * 10
        	END) AS points
FROM dannys_diner.dbo.sales AS S
INNER JOIN dannys_diner.dbo.menu AS M
ON S.product_id = M.product_id
GROUP BY S.customer_id
ORDER BY S.customer_id;

-- Scenario: In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi. 
-- Calculating the points customer A and B have at the end of January
WITH january_points AS (
        SELECT S.customer_id,
                S.order_date,
                MN.product_name,
                MN.price,
                MS.join_date,
                CASE
                    WHEN MN.product_name = 'sushi' THEN MN.price * 20
                    WHEN S.order_date < MS.join_date THEN MN.price * 10
                    WHEN S.order_date = MS.join_date THEN MN.price * 20
                    WHEN S.order_date <= DATEADD(day, 6, MS.join_date) THEN MN.price * 20
                    ELSE MN.price * 10
                END AS points
        FROM dannys_diner.dbo.sales AS S
        INNER JOIN dannys_diner.dbo.menu AS MN
        ON S.product_id = MN.product_id
        LEFT JOIN dannys_diner.dbo.members AS MS
        ON S.customer_id = MS.customer_id
        WHERE MS.join_date IS NOT NULL
                AND S.order_date < '2021-2-1'
  			)
            
SELECT customer_id,
		SUM(points) AS total_january_points
FROM january_points
GROUP BY customer_id;

-- Bonus Question 1: Joining all the things
SELECT S.customer_id,
		S.order_date,
        MN.product_name,
        MN.price,
        CASE
        	WHEN S.order_date < MS.join_date THEN 'N'
            WHEN S.order_date >= MS.join_date THEN 'Y'
            ELSE 'N'
        END AS member
FROM dannys_diner.dbo.sales AS S
INNER JOIN dannys_diner.dbo.menu AS MN
ON S.product_id = MN.product_id
LEFT JOIN dannys_diner.dbo.members AS MS
ON S.customer_id = MS.customer_id
ORDER BY S.customer_id ASC, S.order_date ASC, MN.product_name ASC;

-- Bonus Question 2: Joining and Ranking all the things
WITH all_things AS (
    SELECT S.customer_id,
            S.order_date,
            MN.product_name,
            MN.price,
            CASE
                WHEN S.order_date < MS.join_date THEN 'N'
                WHEN S.order_date >= MS.join_date THEN 'Y'
                ELSE 'N'
            END AS member
    FROM dannys_diner.dbo.sales AS S
    INNER JOIN dannys_diner.dbo.menu AS MN
    ON S.product_id = MN.product_id
    LEFT JOIN dannys_diner.dbo.members AS MS
    ON S.customer_id = MS.customer_id
  		)
        
SELECT *,
		CASE
        	WHEN member = 'N' THEN NULL
            ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date ASC)
        END AS rank
FROM all_things;

