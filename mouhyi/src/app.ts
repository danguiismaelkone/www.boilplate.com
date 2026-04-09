import express from 'express';
import authRoutes from './routes/auth.routes';
const app = express();
app.use(express.json());
app.use('/api/auth', authRoutes);
app.get('/', (_, res) => {
res.send('API running 🚀');
});
export default app;
