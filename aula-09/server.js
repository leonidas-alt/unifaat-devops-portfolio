'use strict';

const express = require('express');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

// ─── Health check ────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    registry: 'Amazon ECR',
  });
});

// ─── Dados em memória ────────────────────────────────────────────────────────
const products = [
  { id: 1, name: 'Notebook TechNova Pro', price: 4999.9, stock: 10 },
  { id: 2, name: 'Monitor UltraWide 34"', price: 2499.9, stock: 5 },
  { id: 3, name: 'Teclado Mecânico RGB',  price:  349.9, stock: 20 },
];

const orders = [
  { id: 1, productId: 1, quantity: 2, status: 'pending'   },
  { id: 2, productId: 2, quantity: 1, status: 'shipped'   },
  { id: 3, productId: 3, quantity: 5, status: 'delivered' },
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
  const { productId, quantity } = req.body;

  if (!productId || !quantity) {
    return res.status(400).json({ error: 'productId and quantity are required' });
  }

  const product = products.find((p) => p.id === parseInt(productId, 10));
  if (!product) {
    return res.status(404).json({ error: 'Product not found' });
  }

  const newOrder = {
    id: orders.length + 1,
    productId: parseInt(productId, 10),
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
    console.log(`TechNova API rodando na porta ${PORT}`);
  });
}

module.exports = app;
