USE classicmodels;

-- =====================================================
-- CALIDAD DE DATOS
-- =====================================================

-- CD-1: ¿Hay países con espacios extra al inicio o al final?
-- (Hallazgo: "Norway" aparecía duplicado por un espacio sobrante)
SELECT DISTINCT country, LENGTH(country) AS largo, LENGTH(TRIM(country)) AS largo_limpio
FROM customers
WHERE LENGTH(country) <> LENGTH(TRIM(country));


-- =====================================================
-- NIVEL 1: UNA TABLA
-- =====================================================

-- N1-P1: ¿Cuántos clientes hay en total?
SELECT COUNT(customerNumber) AS "Total de clientes" FROM customers;

-- N1-P2: ¿En qué países hay clientes? (sin repetir)
SELECT DISTINCT TRIM(country) AS country FROM customers;

-- N1-P3: ¿Cuáles son los 10 productos más caros (MSRP)?
SELECT productName, MSRP FROM products ORDER BY MSRP DESC LIMIT 10;

-- N1-P4: ¿Qué pedidos tienen estado Cancelled?
SELECT orderNumber, status FROM orders WHERE status = 'Cancelled';

-- N1-P5: ¿Qué clientes están en un país específico? (Francia)
SELECT customerName, country FROM customers WHERE country = 'France';


-- =====================================================
-- NIVEL 2: AGRUPAR Y RESUMIR
-- =====================================================

-- N2-P1: ¿Cuántos clientes hay por país, de mayor a menor?
SELECT TRIM(country) AS country, COUNT(customerNumber) AS "Clientes por país"
FROM customers
GROUP BY TRIM(country)
ORDER BY COUNT(customerNumber) DESC;

-- N2-P2: ¿Cuál es el monto total de pagos recibidos?
SELECT SUM(amount) AS "Total de pagos" FROM payments;

-- N2-P3: ¿Cuál es el precio promedio de los productos por línea de producto?
SELECT productLine, AVG(MSRP) AS "Precio promedio"
FROM products
GROUP BY productLine;

-- N2-P4: ¿Qué países tienen más de 5 clientes?
SELECT TRIM(country) AS country, COUNT(country) AS "Clientes"
FROM customers
GROUP BY TRIM(country)
HAVING COUNT(country) > 5
ORDER BY COUNT(country) DESC;

-- N2-P5: Clasificar productos en Barato / Medio / Caro y contarlos
SELECT
CASE
	WHEN MSRP > 100 THEN 'Caro'
	WHEN MSRP >= 50 THEN 'Medio'
	ELSE 'Barato'
END AS Clasificacion,
COUNT(MSRP) AS cantidad
FROM products
GROUP BY Clasificacion;


-- =====================================================
-- NIVEL 3: JOINS
-- =====================================================

-- N3-P1: ¿Qué cliente hizo cada pedido?
SELECT customerName, orderNumber, orderDate
FROM customers
JOIN orders ON customers.customerNumber = orders.customerNumber;

-- N3-P2: ¿Cuántos pedidos ha hecho cada cliente?
SELECT customers.customerName, COUNT(orders.customerNumber) AS "Cantidad de compras"
FROM customers
JOIN orders ON customers.customerNumber = orders.customerNumber
GROUP BY customers.customerNumber, customers.customerName;

-- N3-P3: ¿Cuáles son los ingresos totales por línea de producto?
SELECT productLine, SUM(quantityOrdered*priceEach) AS "Ingresos"
FROM products
JOIN orderdetails ON orderdetails.productCode = products.productCode
GROUP BY productLine;

-- N3-P4: ¿Qué clientes nunca han hecho un pedido?
SELECT customerName AS "Clientes que no han hecho ningun pedido"
FROM customers
LEFT JOIN orders ON customers.customerNumber = orders.customerNumber
WHERE orders.orderNumber IS NULL;

-- N3-P5: ¿Cuántos clientes atiende cada empleado de ventas y de qué oficina es?
SELECT firstName AS "Nombre", lastName AS "Apellido",
COUNT(customers.salesRepEmployeeNumber) AS "Clientes por empleado",
offices.officeCode
FROM employees
JOIN customers ON employees.employeeNumber = customers.salesRepEmployeeNumber
JOIN offices ON employees.officeCode = offices.officeCode
GROUP BY employees.employeeNumber, employees.firstName, employees.lastName, offices.officeCode;


-- =====================================================
-- NIVEL 4: SUBCONSULTAS, CTEs Y AUTO-JOIN
-- =====================================================

-- N4-P1: ¿Qué productos se venden por encima del precio promedio?
SELECT productName, MSRP
FROM products
WHERE MSRP > (SELECT AVG(MSRP) FROM products);

-- N4-P2: Top 10 clientes por ingresos y % que aportan al total
-- Nota: incluye pedidos de todos los estados (también Cancelled y On Hold)
SELECT customers.customerName AS "Nombre",
SUM(orderdetails.quantityOrdered*orderdetails.priceEach) AS "Compras",
ROUND(SUM(orderdetails.quantityOrdered*orderdetails.priceEach)/(SELECT SUM(orderdetails.quantityOrdered*orderdetails.priceEach)
FROM orderdetails)*100,2) AS "Porcentaje"
FROM customers
JOIN orders ON customers.customerNumber = orders.customerNumber
JOIN orderdetails ON orders.orderNumber = orderdetails.orderNumber
GROUP BY customers.customerNumber, customers.customerName
ORDER BY SUM(orderdetails.quantityOrdered*orderdetails.priceEach) DESC
LIMIT 10;

-- N4-P3: ¿Qué clientes superan su límite de crédito frente a lo que han comprado?
-- Nota: el HAVING ya filtra solo a quienes superan el límite
SELECT customers.customerName AS "Nombre",
SUM(orderdetails.quantityOrdered*orderdetails.priceEach) AS "Compras",
customers.creditLimit AS "Limite de credito",
SUM(orderdetails.quantityOrdered*orderdetails.priceEach)-customers.creditLimit AS "Cantidad exceso"
FROM customers
JOIN orders ON customers.customerNumber = orders.customerNumber
JOIN orderdetails ON orders.orderNumber = orderdetails.orderNumber
GROUP BY customers.customerNumber, customers.customerName, customers.creditLimit
HAVING SUM(orderdetails.quantityOrdered*orderdetails.priceEach)-customers.creditLimit > 0
ORDER BY SUM(orderdetails.quantityOrdered*orderdetails.priceEach) DESC;

-- N4-P4: ¿Quién es el jefe de cada empleado? (auto-JOIN)
SELECT empleado.employeeNumber AS "Codigo de empleado",
CONCAT(empleado.firstName, ' ', empleado.lastName) AS "Empleado",
CONCAT(jefe.firstName, ' ', jefe.lastName) AS "Jefe"
FROM employees AS jefe
RIGHT JOIN employees AS empleado ON jefe.employeeNumber = empleado.reportsTo;

-- N4-P5 (parte 1): ¿Qué pedidos se enviaron tarde?
SELECT customerName, orderNumber, shippedDate, requiredDate,
DATEDIFF(shippedDate, requiredDate) AS "Dias de retraso"
FROM classicmodels.orders
JOIN customers ON orders.customerNumber = customers.customerNumber
WHERE shippedDate > requiredDate;

-- N4-P5 (parte 2): ¿Qué porcentaje del total representan?
-- Nota: el total son solo pedidos enviados (shippedDate no nulo),
-- porque el retraso solo se puede medir si el pedido ya salió
SELECT COUNT(*) AS "Pedidos enviados",
SUM(CASE WHEN shippedDate > requiredDate THEN 1 ELSE 0 END) AS "Pedidos tarde",
ROUND(SUM(CASE WHEN shippedDate > requiredDate THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS "Porcentaje tarde"
FROM orders
WHERE shippedDate IS NOT NULL;


-- =====================================================
-- NIVEL 5: WINDOW FUNCTIONS
-- =====================================================

-- N5-P1: Top 3 productos más vendidos de cada línea de producto
-- Nota: RANK incluye a todos los productos empatados en el puesto 3
WITH RankingProducts AS (
SELECT
products.productName,
products.productLine,
SUM(orderdetails.quantityOrdered) AS total_vendido,
RANK() OVER(PARTITION BY products.productLine ORDER BY SUM(orderdetails.quantityOrdered) DESC) AS RANKING
FROM orderdetails
JOIN products ON orderdetails.productCode = products.productCode
GROUP BY products.productName, products.productLine, orderdetails.productCode
)
SELECT productName, productLine, total_vendido, ranking
FROM RankingProducts
WHERE RANKING <= 3
ORDER BY productLine, ranking;

-- N5-P2: Crecimiento porcentual mensual (sobre pagos recibidos)
-- Nota: el primer mes queda en NULL porque no tiene mes anterior
WITH PagosMensuales AS (
SELECT DATE_FORMAT(paymentDate, '%Y-%m') AS Fecha,
SUM(amount) AS Actual,
LAG(SUM(amount)) OVER(ORDER BY DATE_FORMAT(paymentDate, '%Y-%m')) AS Anterior
FROM payments
GROUP BY DATE_FORMAT(paymentDate, '%Y-%m')
)
SELECT Fecha, Actual, ROUND(((Actual-Anterior)/Anterior)*100,2) AS CrecimientoPorcentual
FROM PagosMensuales
ORDER BY Fecha;

-- N5-P3: Ingreso acumulado a lo largo del tiempo (sobre pagos recibidos)
WITH PagosMensuales AS (
SELECT DATE_FORMAT(paymentDate, '%Y-%m') AS Fecha,
SUM(amount) AS VentaMensual
FROM payments
GROUP BY DATE_FORMAT(paymentDate, '%Y-%m')
)
SELECT Fecha, VentaMensual, SUM(VentaMensual) OVER (ORDER BY Fecha) AS IngresoAcumulado
FROM PagosMensuales
ORDER BY Fecha;

-- N5-P4: Cliente con mayor compra en cada país
WITH ComprasPorCliente AS (
SELECT customers.customerNumber AS ID,
customers.customerName AS Nombre,
TRIM(customers.country) AS Pais,
SUM(quantityOrdered*priceEach) AS TotalCompras,
RANK() OVER (PARTITION BY TRIM(customers.country) ORDER BY SUM(quantityOrdered*priceEach) DESC) AS ranking
FROM customers
JOIN orders ON customers.customerNumber = orders.customerNumber
JOIN orderdetails ON orders.orderNumber = orderdetails.orderNumber
GROUP BY customers.customerNumber, customers.customerName, TRIM(customers.country)
)
SELECT ID, Nombre, Pais, TotalCompras, ranking
FROM ComprasPorCliente
WHERE ranking = 1;

-- N5-P5: ¿Cuánto tarda cada cliente en volver a comprar?
-- Nota: los clientes con un solo pedido no aparecen, porque no tienen una segunda compra
WITH TiempoEntreCompras AS (
SELECT customerNumber AS NumeroCliente, orderNumber AS NumeroOrden, orderDate AS FechaPedido,
LAG(orderDate) OVER(PARTITION BY customerNumber ORDER BY orderDate ASC, orderNumber ASC) AS FechaPedidoAnterior
FROM orders
),
PromedioEntreCompras AS (
SELECT NumeroOrden, NumeroCliente, DATEDIFF(FechaPedido, FechaPedidoAnterior) AS DiasDeDiferencia
FROM TiempoEntreCompras
WHERE FechaPedidoAnterior IS NOT NULL
)
SELECT NumeroCliente, ROUND(AVG(DiasDeDiferencia), 2) AS DiasEntreCompras
FROM PromedioEntreCompras
GROUP BY NumeroCliente
ORDER BY DiasEntreCompras;