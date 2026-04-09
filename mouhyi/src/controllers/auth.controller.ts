import { Request, Response } from 'express';
import * as AuthService from '../services/auth.service';
export const register = async (req: Request, res: Response) => {
try {
const { email, password } = req.body;
const user = await AuthService.register(email, password);
res.json(user);
} catch (err: any) {
res.status(400).json({ message: err.message });
}
};
export const login = async (req: Request, res: Response) => {
try {
const { email, password } = req.body;
const data = await AuthService.login(email, password);
res.json(data);
} catch (err: any) {
res.status(401).json({ message: err.message });
}
};
