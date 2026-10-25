create database retail_project;
create table clientes (
id_clientes serial primary key,
Nombre varchar(100) not null ,
email varchar not null unique,
edad integer check (edad>17));
create table productos (
id_productos serial primary key,
nombre varchar not null,
categoria varchar,
precio decimal(10,2) check (precio>0),
stock integer check (stock>-1));
create table ventas (
id_venta serial primary key,
id_clientes integer references clientes(id_clientes),
id_productos integer references productos(id_productos),
fecha DATE,
cantidad INTEGER CHECK (cantidad > 0));
BEGIN;
insert into clientes (nombre, email, edad) values 
('marcelo vega', 'marcelovega@gmail.com', 37),
('joelmartinez', 'joelmartinez@gmail.com', 28),
('elias torancio', 'eliastorancio@gmail.com.ar', 30),
('nahuel yzaurralde', 'yza1899@gmail.com', 23),
('fernando cosciuc', 'fercosciuc@yahoo.com', 29);
insert into productos (nombre, categoria, precio, stock) values 
('botin nike f90', 'futbol', 150000.00, 30), 
('camiseta argentino de quilmes', 'futbol', 113458.80, 20), 
('pelota wilson n7', 'basket', 120000.00, 17), 
('camiseta peñarol mdp', 'basket', 80000.00, 11), 
('camiseta blue jays', 'baseball', 150000.00, 8);
INSERT INTO ventas (id_clientes, id_productos, fecha, cantidad) VALUES
(1, 1, '2026-09-01', 2), 
(1, 4, '2026-08-20', 1), 
(4, 5, '2026-09-10', 1), 
(5, 2, '2026-09-11', 3), 
(2, 2, '2026-09-11', 1);
COMMIT;
UPDATE productos
SET precio = precio * 1.05
WHERE categoria = 'futbol';
SELECT * FROM ventas
WHERE id_venta = 5;
DELETE FROM ventas
WHERE id_venta = 5;
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO categorias (nombre)
SELECT DISTINCT p.categoria
FROM productos AS p
WHERE p.categoria IS NOT NULL
ON CONFLICT (nombre) DO NOTHING
SELECT c.nombre AS categoria,
    SUM(v.cantidad) AS unidades_vendidas,
    SUM(v.cantidad * p.precio) AS ingreso_total
FROM ventas AS v
JOIN productos AS p ON v.id_productos = p.id_productos
JOIN categorias AS c ON p.categoria = c.nombre
GROUP BY c.id_categoria, c.nombre
HAVING SUM(v.cantidad * p.precio) > 100000
ORDER BY ingreso_total DESC;
SELECT c.id_clientes,
    c.nombre AS cliente,
    COALESCE(SUM(v.cantidad), 0) AS unidades_compradas
FROM clientes AS c
LEFT JOIN ventas AS v ON c.id_clientes = v.id_clientes
GROUP BY c.id_clientes, c.nombre
HAVING COUNT(v.id_venta) = 0
ORDER BY c.nombre;
WITH compras_por_producto AS (
    SELECT c.id_clientes,
        c.nombre AS cliente,
        p.nombre AS producto,
        COUNT(v.id_venta) AS veces_comprado,
        SUM(v.cantidad) AS unidades_compradas,
        ROW_NUMBER() OVER (
            PARTITION BY c.id_clientes
            ORDER BY COUNT(v.id_venta) DESC,
                     SUM(v.cantidad) DESC,
                     p.nombre ASC
        ) AS posicion
    FROM clientes AS c
    JOIN ventas AS v ON c.id_clientes = v.id_clientes
    JOIN productos AS p ON v.id_productos = p.id_productos
    GROUP BY c.id_clientes, c.nombre, p.id_productos, p.nombre
), ultima_compra AS (
    SELECT id_clientes, MAX(fecha) AS ultima_transaccion
    FROM ventas
    GROUP BY id_clientes
)
SELECT cp.cliente,
    cp.producto AS producto_mas_comprado,
    cp.veces_comprado,
    cp.unidades_compradas,
    uc.ultima_transaccion
FROM compras_por_producto AS cp
JOIN ultima_compra AS uc ON cp.id_clientes = uc.id_clientes
WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', v.fecha)::DATE AS mes,
        COALESCE(p.categoria, 'Sin categorizar') AS categoria,
        SUM(v.cantidad * p.precio) AS total_ventas
    FROM ventas v
    INNER JOIN productos p
        ON v.id_productos = p.id_productos
    GROUP BY
        DATE_TRUNC('month', v.fecha)::DATE,
        COALESCE(p.categoria, 'Sin categorizar')
),
metricas_ventana AS (
    SELECT
        mes,
        categoria,
        total_ventas,

        RANK() OVER (
            PARTITION BY mes
            ORDER BY total_ventas DESC
        ) AS ranking_mensual,

        SUM(total_ventas) OVER (
            PARTITION BY categoria
            ORDER BY mes
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS ventas_acumuladas,

        AVG(total_ventas) OVER (
            PARTITION BY categoria
        ) AS promedio_categoria

    FROM ventas_mensuales
)

SELECT
    mes,
    categoria,
    total_ventas,
    ranking_mensual,
    ventas_acumuladas,
    ROUND(promedio_categoria, 2) AS promedio_categoria,

    CASE
        WHEN total_ventas >= promedio_categoria
            THEN 'Exitoso'
        ELSE 'Bajo el promedio'
    END AS rendimiento_mes

FROM metricas_ventana

ORDER BY mes, ranking_mensual, categoria;