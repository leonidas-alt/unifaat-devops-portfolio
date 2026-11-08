const request = require('supertest');
const app = require('../server');

// ─── Health Check ─────────────────────────────────────────────────────────────
describe('Health Check', () => {
  it('GET /health deve retornar status 200', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
  });

  it('GET /health deve retornar status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.body.status).toBe('ok');
  });

  it('GET /health deve retornar timestamp', async () => {
    const res = await request(app).get('/health');
    expect(res.body.timestamp).toBeDefined();
  });

  it('GET /health deve retornar campo sha', async () => {
    const res = await request(app).get('/health');
    expect(res.body.sha).toBeDefined();
  });
});

// ─── Products API ─────────────────────────────────────────────────────────────
describe('Products API', () => {
  it('GET /api/products deve retornar array', async () => {
    const res = await request(app).get('/api/products');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('GET /api/products deve retornar produtos com campos corretos', async () => {
    const res = await request(app).get('/api/products');
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('name');
    expect(res.body[0]).toHaveProperty('price');
    expect(res.body[0]).toHaveProperty('stock');
  });

  it('GET /api/products/:id deve retornar produto específico', async () => {
    const res = await request(app).get('/api/products/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(1);
  });

  it('GET /api/products/:id deve retornar 404 para id inexistente', async () => {
    const res = await request(app).get('/api/products/999');
    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Product not found');
  });
});

// ─── Orders API ───────────────────────────────────────────────────────────────
describe('Orders API', () => {
  it('GET /api/orders deve retornar array', async () => {
    const res = await request(app).get('/api/orders');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('GET /api/orders deve retornar orders com campos corretos', async () => {
    const res = await request(app).get('/api/orders');
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('product');
    expect(res.body[0]).toHaveProperty('quantity');
    expect(res.body[0]).toHaveProperty('status');
  });

  it('GET /api/orders/:id deve retornar order específica', async () => {
    const res = await request(app).get('/api/orders/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(1);
  });

  it('GET /api/orders/:id deve retornar 404 para id inexistente', async () => {
    const res = await request(app).get('/api/orders/999');
    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Order not found');
  });

  it('POST /api/orders deve criar nova order', async () => {
    const newOrder = { product: 'Mouse Gamer', quantity: 3 };
    const res = await request(app).post('/api/orders').send(newOrder);
    expect(res.statusCode).toBe(201);
    expect(res.body.product).toBe('Mouse Gamer');
    expect(res.body.quantity).toBe(3);
    expect(res.body.status).toBe('pending');
  });

  it('POST /api/orders deve retornar 400 sem campos obrigatórios', async () => {
    const res = await request(app).post('/api/orders').send({});
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('POST /api/orders deve retornar 400 sem product', async () => {
    const res = await request(app).post('/api/orders').send({ quantity: 1 });
    expect(res.statusCode).toBe(400);
  });

  it('POST /api/orders deve retornar 400 sem quantity', async () => {
    const res = await request(app).post('/api/orders').send({ product: 'Teclado' });
    expect(res.statusCode).toBe(400);
  });
});
