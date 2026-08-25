const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 5000;
const pool = new Pool({
    host: process.env.DB_HOST || "localhost",
    port: process.env.DB_PORT || 5432,
    user: process.env.DB_USER || "nimbus",
    password: process.env.DB_PASSWORD || "nimbuspass",
    database: process.env.DB_NAME || "nimbuscart"
});
async function initializeDatabase() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS products (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            price NUMERIC(10,2) NOT NULL,
            stock INTEGER NOT NULL
        );
    `);

    console.log("Database initialized");
}
app.get("/health", async (req, res) => {
    res.status(200).json({
        status: "OK"
    });
});
app.get("/items", async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT * FROM products ORDER BY id"
        );

        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({
            error: "Failed to fetch products"
        });
    }
});
app.post("/items", async (req, res) => {
    try {
        const { name, price, stock } = req.body;

        if (!name || price === undefined || stock === undefined) {
            return res.status(400).json({
                error: "name, price and stock are required"
            });
        }

        const result = await pool.query(
            `
            INSERT INTO products (name, price, stock)
            VALUES ($1, $2, $3)
            RETURNING *
            `,
            [name, price, stock]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({
            error: "Failed to add product"
        });
    }
});

async function startServer() {
    try {
        await initializeDatabase();
        app.listen(PORT, () => {
            console.log(`API running on port ${PORT}`);
        });
    } catch (error) {
        console.error("Failed to initialize application:", error);
        process.exit(1);
    }
}
startServer();
