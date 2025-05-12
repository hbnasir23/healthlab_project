import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart/cart_provider.dart';
import 'cart/cart_screen.dart';
import '../../../constants.dart';

class UserPharmacyScreen extends StatefulWidget {
  const UserPharmacyScreen({super.key});

  @override
  _UserPharmacyScreenState createState() => _UserPharmacyScreenState();
}

class _UserPharmacyScreenState extends State<UserPharmacyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: AppConstants.deviceHeight * 0.04),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pharmacy',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Image.asset(
                  'assets/images/logo.png',
                  height: MediaQuery.of(context).size.height * 0.08,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client.from('pharmacy').select(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No items available'));
                }

                return Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.64,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return _buildPharmacyItemCard(item, cartProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          ).then((_) {
            setState(() {});
          });
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shopping_cart,
                size: 28,
                color: Colors.white,
              ),
            ),
            Positioned(
              right: 0,
              child: Consumer<CartProvider>(
                builder: (context, cart, child) {
                  return cart.items.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.red,
                        radius: 10,
                        child: Text(
                          cart.items.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacyItemCard(
    Map<String, dynamic> item,
    CartProvider cartProvider,
  ) {
    // Calculate how many of this item are in the cart
    int cartQuantity = 0;
    for (var cartItem in cartProvider.items) {
      if (cartItem.id == item['id']) {
        cartQuantity = cartItem.quantity;
        break;
      }
    }

    // Calculate available quantity
    int availableQuantity = item['quantity'] - cartQuantity;

    return SizedBox(
      child: GestureDetector(
        onTap: () => _showItemDetails(item, cartQuantity),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Image.network(
                  item['photo'] ?? '',
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.medication, size: 100);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Rs. ${item['price']}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Available: $availableQuantity',
                      style: TextStyle(
                        color:
                            availableQuantity > 0 ? Colors.black : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item, int cartQuantity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            item['photo'] ?? '',
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.medication, size: 200);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          item['name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Rs. ${item['price']}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Description: ${item['description']}',
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Consumer<CartProvider>(
                          builder: (context, cart, child) {
                            // Recalculate cart quantity in case it changes
                            int currentCartQuantity = 0;
                            for (var cartItem in cart.items) {
                              if (cartItem.id == item['id']) {
                                currentCartQuantity = cartItem.quantity;
                                break;
                              }
                            }

                            int currentAvailable =
                                item['quantity'] - currentCartQuantity;

                            return Column(
                              children: [
                                Text('Available Quantity: $currentAvailable'),
                                const SizedBox(height: 10),
                                if (currentCartQuantity > 0)
                                  Text(
                                    'In Cart: $currentCartQuantity',
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed:
                                      currentAvailable > 0
                                          ? () {
                                            Provider.of<CartProvider>(
                                              context,
                                              listen: false,
                                            ).addToCart(
                                              CartItem(
                                                id: item['id'],
                                                name: item['name'],
                                                price: item['price'].toDouble(),
                                                photo: item['photo'],
                                              ),
                                            );
                                            Navigator.pop(context);
                                            setState(() {}); // Refresh the UI
                                          }
                                          : null,
                                  child: const Text('Add to Cart'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      50,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}
