'use strict';

const express = require('express');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

// ─── Health check ────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    sha: process.env.GITHUB_SHA || 'local',
    environment: process.env.NODE_ENV || 'development',
  });
});

// ─── Dados em memória ────────────────────────────────────────────────────────
const products = [
  { id: 1, name: 'Notebook TechNova Pro', price: 4999.90, stock: 10 },
  { id: 2, name: 'Monitor UltraWide 34"', price: 2499.90, stock: 5 },
  { id: 3, name: 'Teclado Mecânico RGB', price: 349.90, stock: 20 },
];

const orders = [
  { id: 1, product: 'Notebook TechNova Pro', quantity: 2, status: 'pending' },
  { id: 2, product: 'Monitor UltraWide 34"', quantity: 1, status: 'shipped' },
  { id: 3, product: 'Teclado Mecânico RGB', quantity: 5, status: 'delivered' },
];

// ─── Produtos ────────────────────────────────────────────────────────────────
app.get('/api/products', (_req, res) => {
  res.json(products);
});

app.get('/api/products/:id', (req, res) => {
  const product = products.find((p) => p.id === parseInt(req.params.id, 10));
  if (!product) {
    return res.status(404).json({ error: 'Product not found' });
  }
  return res.json(product);
});

// ─── Pedidos ─────────────────────────────────────────────────────────────────
app.get('/api/orders', (_req, res) => {
  res.json(orders);
});

app.get('/api/orders/:id', (req, res) => {
  const order = orders.find((o) => o.id === parseInt(req.params.id, 10));
  if (!order) {
    return res.status(404).json({ error: 'Order not found' });
  }
  return res.json(order);
});

app.post('/api/orders', (req, res) => {
  const { product, quantity } = req.body;

  if (!product || !quantity) {
    return res.status(400).json({ error: 'product and quantity are required' });
  }

  const newOrder = {
    id: orders.length + 1,
    product: String(product),
    quantity: parseInt(quantity, 10),
    status: 'pending',
  };
  orders.push(newOrder);
  return res.status(201).json(newOrder);
});

// ─── Inicia servidor (fora do modo test) ─────────────────────────────────────
if (process.env.NODE_ENV !== 'test') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`TechNova API rodando na porta ${PORT} | SHA: ${process.env.GITHUB_SHA || 'local'}`);
  });
}

module.exports = app;


