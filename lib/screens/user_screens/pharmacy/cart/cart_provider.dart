import 'package:flutter/foundation.dart';

class CartItem {
  final int id;
  final String name;
  final double price;
  final String photo;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.photo,
    this.quantity = 1,
  });
  @override
  String toString() {
    return 'CartItem(name: $name, quantity: $quantity, price: $price, photo: $photo)';
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalAmount {
    return _items.fold(0.0, (total, item) => total + (item.price * item.quantity));
  }

  void addToCart(CartItem item) {
    // Check if item already exists in cart
    for (var cartItem in _items) {
      if (cartItem.id == item.id) {
        cartItem.quantity++;
        notifyListeners();
        return;
      }
    }

    // If item not in cart, add new item
    _items.add(item);
    notifyListeners();
  }

  void removeFromCart(int id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void updateQuantity(int id, int newQuantity) {
    for (var item in _items) {
      if (item.id == id) {
        item.quantity = newQuantity;
        break;
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}