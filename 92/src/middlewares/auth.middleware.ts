import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
const JWT_SECRET = 'secret';
export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
const header = req.headers.authorization;
if (!header) {
return res.status(401).json({ message: 'No token' });
}
const token = header.split(' ')[1];
try {
const decoded = jwt.verify(token, JWT_SECRET);
(req as any).user = decoded;
next();
} catch {
res.status(401).json({ message: 'Invalid token' });
}
};
