import { users, User } from '../models/user.model';
import { hashPassword, comparePassword } from '../utils/hash';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
const JWT_SECRET = 'secret';
export const register = async (email: string, password: string) => {
const existing = users.find(u => u.email === email);
if (existing) throw new Error('User already exists');
const hashed = await hashPassword(password);
const user: User = {
id: uuidv4(),
email,
password: hashed,
};
users.push(user);
return { id: user.id, email: user.email };
};
export const login = async (email: string, password: string) => {
const user = users.find(u => u.email === email);
if (!user) throw new Error('Invalid credentials');
const isValid = await comparePassword(password, user.password);
if (!isValid) throw new Error('Invalid credentials');
const token = jwt.sign(
{ id: user.id, email: user.email },
JWT_SECRET,
{ expiresIn: '1d' }
);
return { token };
};
