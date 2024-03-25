CREATE SCHEMA sqlchallenge_week1_dannys_diner;
USE sqlchallenge_week1_dannys_diner;

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER,
  PRIMARY KEY (product_id)
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE,
  PRIMARY KEY (customer_id)
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
  CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
  
  /* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id as 'Customer', SUM(price*count_product) as 'Total amount spent'
FROM (SELECT customer_id, sales.product_id, COUNT(sales.product_id) as count_product, price
		FROM sales, menu
		WHERE sales.product_id = menu.product_id
		GROUP BY customer_id, sales.product_id) as countproduct
GROUP BY customer_id
ORDER BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id as 'Customer', COUNT(order_date) as 'Number of days visited'
FROM (SELECT customer_id, order_date
		FROM sales
        GROUP BY customer_id, order_date) as distinct_order_date
GROUP BY customer_id
ORDER BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT customer_id as 'Customer', product_name as 'First item purchased'
FROM (SELECT customer_id, order_date, product_id, ROW_NUMBER() OVER (PARTITION BY customer_id
																	ORDER BY order_date ASC) as row_num
		FROM sales) sub, menu m
WHERE row_num = 1
AND sub.product_id = m.product_id
ORDER BY customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_name 'Item', COUNT(s.product_id) 'Number of times purchased'
FROM sales s, menu m
WHERE s.product_id = m.product_id
GROUP BY s.product_id
HAVING COUNT(s.product_id) = (SELECT MAX(count_item)
								FROM (SELECT product_id, COUNT(product_id) as count_item
										FROM sales
										GROUP BY product_id) counting);
                                        
-- 5. Which item was the most popular for each customer?
SELECT customer_id 'Customer', product_name 'Most popular item', count_item
FROM (SELECT customer_id, product_id, COUNT(product_id) as count_item, DENSE_RANK() OVER (PARTITION BY customer_id
																							ORDER BY COUNT(product_id) DESC) as rank_count
		FROM sales
		GROUP BY customer_id, product_id) sub, menu m
WHERE m.product_id = sub.product_id
AND rank_count = 1
ORDER BY customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
SELECT customer_id 'Customer', product_name 'Item first purchased after becoming member'
FROM (SELECT s.customer_id, product_id, order_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date ASC) as order_row
		FROM sales s, members m
		WHERE s.customer_id = m.customer_id
		AND order_date > join_date) sub, menu m
WHERE order_row = 1
AND sub.product_id = m.product_id
ORDER BY customer_id;

-- 7. Which item was purchased just before the customer became a member?
SELECT customer_id 'Customer', product_name 'Item purchased just before becoming a member'
FROM (SELECT s.customer_id, product_id, order_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) as order_row
		FROM sales s, members m
		WHERE s.customer_id = m.customer_id
		AND order_date < join_date) order_before, menu m
WHERE order_row = 1
AND order_before.product_id = m.product_id
ORDER BY customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT customer_id 'Customer', SUM(count_item) as 'Total items', SUM(total_spending) as 'Amount spent'
FROM (SELECT s.customer_id, s.product_id, COUNT(s.product_id) as count_item, price*COUNT(s.product_id) as total_spending
		FROM sales s, menu m, members mem
		WHERE s.customer_id = mem.customer_id
		AND s.product_id = m.product_id
        AND order_date < join_date
		GROUP BY s.customer_id, s.product_id) total_item
GROUP BY customer_id
ORDER BY customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT customer_id as 'Customer', SUM(points) as 'Total points'
FROM (SELECT s.customer_id, s.product_id, COUNT(s.product_id) as count_item, IF(product_name = 'sushi', price*COUNT(s.product_id)*2*10, price*COUNT(s.product_id)*10) as points
		FROM sales s, menu m, members mem
		WHERE s.product_id = m.product_id
		AND s.customer_id = mem.customer_id
		AND order_date > join_date
		GROUP BY s.customer_id, s.product_id) point_calc
GROUP BY customer_id
ORDER BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH union_table AS (	(SELECT s.customer_id, s.product_id, COUNT(s.product_id) as count_item, price*COUNT(s.product_id)*10*2 as points
						FROM sales s, menu m, members mem
						WHERE s.product_id = m.product_id
						AND s.customer_id = mem.customer_id
						AND order_date >= join_date
						AND DATEDIFF(order_date, join_date) < 7
						GROUP BY s.customer_id, s.product_id)
					UNION ALL
						(SELECT s.customer_id, s.product_id, COUNT(s.product_id) as count_item, IF(product_name = 'sushi', price*COUNT(s.product_id)*2*10, price*COUNT(s.product_id)*10) as points
						FROM sales s, menu m, members mem
						WHERE s.product_id = m.product_id
						AND s.customer_id = mem.customer_id
						AND order_date > join_date
						AND DATEDIFF(order_date, join_date) >= 7
						GROUP BY s.customer_id, s.product_id))
SELECT customer_id 'Customer', SUM(points) 'Total points'
FROM union_table
WHERE customer_id IN ('A', 'B')
GROUP BY customer_id
ORDER BY customer_id;

/* --------------------
   Bonus Questions
   --------------------*/
   
-- 1. Recreate the given table output with 'customer_id', 'order_date', 'product_name', 'price', 'member'
SELECT s.customer_id, order_date, product_name, price, IF((order_date < join_date) OR (join_date IS NULL), 'N', 'Y') as 'member'
FROM sales s LEFT JOIN members mem ON s.customer_id = mem.customer_id
			INNER JOIN menu m ON s.product_id = m.product_id
ORDER BY customer_id ASC, order_date ASC, price DESC;

-- 2. Recreate the given table output with 'customer_id', 'order_date', 'product_name', 'price', 'member', 'ranking'
SELECT *, IF(member = 'Y', RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date ASC, price DESC), NULL) as 'ranking'
FROM (SELECT s.customer_id, order_date, product_name, price, IF((order_date < join_date) OR (join_date IS NULL), 'N', 'Y') as 'member'
		FROM sales s LEFT JOIN members mem ON s.customer_id = mem.customer_id
					INNER JOIN menu m ON s.product_id = m.product_id
		ORDER BY customer_id ASC, order_date ASC, price DESC) customer_data;