export interface CartItem {
  id: string;
  price: number;
  quantity: number;
}

export interface Cart {
  items: CartItem[];
  total: number;
}

export const CART_URL = "https://api.example.com/cart";

/** Loads the cart with the global fetch; a non-2xx status is an error. */
export async function fetchCart(): Promise<Cart> {
  const response = await fetch(CART_URL);
  if (!response.ok) {
    throw new Error(`GET /cart failed with status ${response.status}`);
  }
  return (await response.json()) as Cart;
}
