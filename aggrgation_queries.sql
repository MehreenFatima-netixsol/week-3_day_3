--------PART 1-----------
-- Find the Total Revenue generated per score
SELECT
	s.store_id,
	SUM(p.amount) AS total_revenue
FROM payment p
JOIN staff st
ON p.staff_id = st.staff_id
JOIN store s
 ON st.store_id=s.store_id
GROUP BY s.store_id
ORDER BY total_revenue DESC;

--Find the average rental duration per film category
SELECT 
c.name AS category,
AVG(f.rental_duration) AS average_rental_duration
FROM film f
JOIN film_category fc
ON f.film_id = fc.film_id
JOIN category c
ON fc.category_id = c.category_id
GROUP BY c.name
ORDER BY average_rental_duration DESC;

--Find the number of rentals made each month
SELECT
EXTRACT(MONTH FROM rental_date) AS month,
COUNT(*) AS total_rentals
FROM rental
GROUP BY month
ORDER BY month;

--Find categories with more than 50 films
SELECT
    c.name,
    COUNT(*) AS total_films
FROM category c
JOIN film_category fc
    ON c.category_id = fc.category_id
GROUP BY c.name
HAVING COUNT(*) > 50
ORDER BY total_films DESC;
---------PART 2-----------
--Subquery Challenges
SELECT
    customer_id,
    SUM(amount) AS total_spent
FROM payment
GROUP BY customer_id
HAVING SUM(amount) >
(
    SELECT AVG(customer_total)
    FROM
    (
        SELECT SUM(amount) AS customer_total
        FROM payment
        GROUP BY customer_id
    ) avg_table
)
ORDER BY total_spent DESC;
--Find the film(s) with the highest rental rate in each category.
-- Correlated Subquery
SELECT
    c.name AS category,
    f.title,
    f.rental_rate
FROM film f
JOIN film_category fc
    ON f.film_id = fc.film_id
JOIN category c
    ON fc.category_id = c.category_id
WHERE f.rental_rate =
(
    SELECT MAX(f2.rental_rate)
    FROM film f2
    JOIN film_category fc2
        ON f2.film_id = fc2.film_id
    WHERE fc2.category_id = fc.category_id
)
ORDER BY category;
--Find customers who have never rented a film.
SELECT
    c.customer_id,
    c.first_name,
    c.last_name
FROM customer c
WHERE NOT EXISTS
(
    SELECT 1
    FROM rental r
    WHERE r.customer_id = c.customer_id
);
-- Find the store with the highest total revenue.

SELECT
    revenue.store_id,
    revenue.total_revenue
FROM
(
    SELECT
        s.store_id,
        SUM(p.amount) AS total_revenue
    FROM payment p
    JOIN staff st
        ON p.staff_id = st.staff_id
    JOIN store s
        ON st.store_id = s.store_id
    GROUP BY s.store_id
) revenue
WHERE total_revenue =
(
    SELECT MAX(total_revenue)
    FROM
    (
        SELECT
            SUM(p.amount) AS total_revenue
        FROM payment p
        JOIN staff st
            ON p.staff_id = st.staff_id
        GROUP BY st.store_id
    ) x
);
-------PART 3----------
--CTE And Window Functions
-- Rank customers by total spend within each city.

WITH customer_spending AS
(
    SELECT
        ci.city,
        c.customer_id,
        c.first_name,
        c.last_name,
        SUM(p.amount) AS total_spent
    FROM customer c
    JOIN address a
        ON c.address_id = a.address_id
    JOIN city ci
        ON a.city_id = ci.city_id
    JOIN payment p
        ON c.customer_id = p.customer_id
    GROUP BY
        ci.city,
        c.customer_id,
        c.first_name,
        c.last_name
)

SELECT *,
RANK() OVER
(
    PARTITION BY city
    ORDER BY total_spent DESC
) AS customer_rank
FROM customer_spending
ORDER BY city, customer_rank;

--Find the most recently rented film for each customer.
WITH latest_rental AS
(
    SELECT
        r.customer_id,
        f.title,
        r.rental_date,
        ROW_NUMBER() OVER
        (
            PARTITION BY r.customer_id
            ORDER BY r.rental_date DESC
        ) AS rn
    FROM rental r
    JOIN inventory i
        ON r.inventory_id = i.inventory_id
    JOIN film f
        ON i.film_id = f.film_id
)

SELECT
    customer_id,
    title,
    rental_date
FROM latest_rental
WHERE rn = 1
ORDER BY customer_id;
--Calculate month-over-month rental revenue growth.

WITH monthly_revenue AS
(
    SELECT
        DATE_TRUNC('month', payment_date) AS month,
        SUM(amount) AS revenue
    FROM payment
    GROUP BY DATE_TRUNC('month', payment_date)
)

SELECT
    month,
    revenue,
    LAG(revenue) OVER
    (
        ORDER BY month
    ) AS previous_month,
    ROUND(
        (
            revenue -
            LAG(revenue) OVER (ORDER BY month)
        )
        /
        LAG(revenue) OVER (ORDER BY month)
        *100,
        2
    ) AS growth_percentage
FROM monthly_revenue
ORDER BY month;

--Top 3 highest-grossing films per category.

WITH film_revenue AS
(
    SELECT
        c.name AS category,
        f.title,
        SUM(p.amount) AS revenue
    FROM payment p
    JOIN rental r
        ON p.rental_id = r.rental_id
    JOIN inventory i
        ON r.inventory_id = i.inventory_id
    JOIN film f
        ON i.film_id = f.film_id
    JOIN film_category fc
        ON f.film_id = fc.film_id
    JOIN category c
        ON fc.category_id = c.category_id
    GROUP BY
        c.name,
        f.title
),

ranked_films AS
(
    SELECT *,
    RANK() OVER
    (
        PARTITION BY category
        ORDER BY revenue DESC
    ) AS ranking
    FROM film_revenue
)

SELECT *
FROM ranked_films
WHERE ranking <= 3
ORDER BY category, ranking;

--BONUS
WITH staff_revenue AS
(
    SELECT
        st.store_id,
        st.staff_id,
        st.first_name,
        st.last_name,
        SUM(p.amount) AS revenue
    FROM payment p
    JOIN staff st
        ON p.staff_id = st.staff_id
    GROUP BY
        st.store_id,
        st.staff_id,
        st.first_name,
        st.last_name
),

store_totals AS
(
    SELECT
        store_id,
        SUM(revenue) AS total_store_revenue
    FROM staff_revenue
    GROUP BY store_id
),

ranked_staff AS
(
    SELECT
        sr.*,
        st.total_store_revenue,
        RANK() OVER
        (
            PARTITION BY sr.store_id
            ORDER BY revenue DESC
        ) AS ranking
    FROM staff_revenue sr
    JOIN store_totals st
        ON sr.store_id = st.store_id
)

SELECT
    store_id,
    staff_id,
    first_name,
    last_name,
    revenue,
    total_store_revenue,
    ROUND(
        revenue * 100.0 / total_store_revenue,
        2
    ) AS contribution_percentage
FROM ranked_staff
WHERE ranking = 1;








