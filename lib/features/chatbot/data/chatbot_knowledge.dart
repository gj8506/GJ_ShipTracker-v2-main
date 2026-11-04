import '../../../core/constants/app_constants.dart';

/// Static knowledge base for the in-app assistant.
///
/// This feature is intentionally offline: it contains no Firebase imports and
/// never queries Firestore. Anything that asks for live records is refused by
/// [ChatbotKnowledge.isDataAccessRequest] before intent matching can run.
class ChatIntent {
  final List<String> keywords;
  final String response;
  final List<String>? quickReplies;
  final String? actionLabel;
  final String? actionRoute;
  final List<String> allowedRoles;

  const ChatIntent({
    required this.keywords,
    required this.response,
    this.quickReplies,
    this.actionLabel,
    this.actionRoute,
    required this.allowedRoles,
  });
}

class ChatbotKnowledge {
  static const String fallbackResponse =
      "I'm your virtual app guide, but I didn't quite catch that. Try one of the quick replies below, or ask me how to use orders, dispatching, returns, or privacy. I can't look up records or account data.";

  static const String legalRefusalResponse =
      "I cannot provide legal advice regarding the LTO compliance of temporary plates. Please consult official local transportation guidelines.";

  /// The assistant is a static, offline app guide. It must never read
  /// Firestore, so anything that asks it to look up live records is refused
  /// here before intent matching can produce a misleading answer.
  static const String dataAccessRefusalResponse =
      "I'm an app guide only, so I can't open Firebase records, customer details, or sales figures. Please use Parcels, Analytics, Search Summary, or the relevant screen in the app to see live data.";

  /// Phrases that ask for live database content rather than app guidance.
  ///
  /// The list is intentionally broad: when in doubt the assistant refuses and
  /// points the user at the screen that owns the data. It never opens Firestore.
  static const List<String> dataRequestKeywords = [
    // Counts and totals
    'how many orders',
    'how many parcels',
    'how many customers',
    'how many users',
    'number of orders',
    'number of parcels',
    'number of customers',
    'number of users',
    'count of orders',
    'count of parcels',
    'count of customers',
    'total orders',
    'total parcels',
    'total customers',
    'total sales',
    'total revenue',
    'total earnings',
    'total income',
    'total profit',
    'sales today',
    'revenue today',
    'earnings today',
    'profit today',
    'sales this week',
    'sales this month',
    'monthly sales',
    'monthly revenue',
    // Lists and record browsing
    'list of orders',
    'list of parcels',
    'list of customers',
    'list of users',
    'customer list',
    'order list',
    'parcel list',
    'user list',
    'all orders',
    'all parcels',
    'all customers',
    'all users',
    'show me the orders',
    'show me the parcels',
    'show me the customers',
    'show me the users',
    'show me all',
    'show orders',
    'show parcels',
    'show customers',
    'show users',
    'show sales',
    'show revenue',
    'show the data',
    'show me the data',
    'raw data',
    // Specific records and lookups
    'database',
    'firestore',
    'firebase',
    'records',
    'record of',
    'records of',
    'query the',
    'query firestore',
    'query firebase',
    'query the database',
    'read the database',
    'access the database',
    'read firebase',
    'access firebase',
    'from the database',
    'from firestore',
    'from firebase',
    'look up order',
    'look up parcel',
    'look up customer',
    'look up user',
    'find order',
    'find parcel',
    'find customer',
    'find user',
    'search for order',
    'search for parcel',
    'search for customer',
    'search records',
    'who ordered',
    'who is the customer',
    'who are the customers',
    'order details',
    'parcel details',
    'customer details',
    'user details',
    'account details',
    'order history',
    'purchase history',
    'transaction history',
    'status of order',
    'status of parcel',
    'tracking number of',
    'address of',
    'phone number of',
    'contact number of',
    'email of',
    'customer address',
    'customer phone',
    'customer email',
    'pending orders',
    'pending parcels',
    'delivered orders',
    'delivered parcels',
    // Exports and bulk access
    'export data',
    'export the data',
    'download data',
    'download the data',
    'dump the database',
  ];

  /// True when [input] asks the assistant to reveal database content.
  static bool isDataAccessRequest(String input) {
    final lower = input.toLowerCase();
    return dataRequestKeywords.any(lower.contains);
  }

  // SAMPLE CONTENT: Replace prices and timelines with your actual business logic

  static const List<ChatIntent> intents = [
    // --- CUSTOMER INTENTS ---
    ChatIntent(
      keywords: ['order', 'buy', 'purchase', 'new plate', 'how to order'],
      response:
          "Ordering a custom plate is easy! Our standard plates cost ₱1450.00 (SAMPLE). Go to the 'New Plate' tab, fill in your plate details, and submit the request. We will review it shortly.",
      quickReplies: ['Track my order', 'Report a defect'],
      actionLabel: 'Order Now',
      actionRoute: '/customer/new-order',
      allowedRoles: [AppConstants.roleCustomer],
    ),
    ChatIntent(
      keywords: ['track', 'status', 'where', 'my order', 'dispatch'],
      response:
          "You can track the live status of your plate in the 'My Orders' tab. Once staff processes your request, your courier tracking number will appear there.",
      quickReplies: ['Order a plate', 'Report a defect'],
      actionLabel: 'View My Orders',
      actionRoute: '/customer/orders',
      allowedRoles: [AppConstants.roleCustomer],
    ),
    ChatIntent(
      keywords: ['defect', 'broken', 'wrong', 'return', 'refund', 'issue'],
      response:
          "I'm sorry to hear there's an issue with your plate! Please navigate to the Support tab to open a direct chat with our Admin and upload photos of the defect.",
      quickReplies: ['Track my order'],
      allowedRoles: [AppConstants.roleCustomer],
    ),

    // --- STAFF / ADMIN INTENTS ---
    ChatIntent(
      keywords: ['dispatch', 'send', 'courier', 'process order'],
      response:
          "To process an order, go to the Dispatch tab. If it's a repeat customer, use the QR Scanner to autofill their details instantly!",
      quickReplies: ['Scan QR', 'Analytics'],
      actionLabel: 'Go to Dispatch',
      actionRoute: '/dispatch',
      allowedRoles: [AppConstants.roleStaff, AppConstants.roleAdmin],
    ),
    ChatIntent(
      keywords: ['scan', 'qr', 'reseller', 'walk-in'],
      response:
          "Scanning a customer's QR code instantly fills out the dispatch form with their details and courier preferences.",
      quickReplies: ['Dispatch an order', 'View returns'],
      actionLabel: 'Open Scanner',
      actionRoute: '/profile/reseller-scanner',
      allowedRoles: [AppConstants.roleStaff, AppConstants.roleAdmin],
    ),
    ChatIntent(
      keywords: ['analytics', 'sales', 'chart', 'export', 'excel'],
      response:
          "The Analytics dashboard shows your revenue trends. You can also export a fully organized Excel sheet from the top right corner. Note: Only Admins can access this.",
      quickReplies: ['Dispatch an order'],
      actionLabel: 'View Analytics',
      actionRoute: '/analytics',
      allowedRoles: [AppConstants.roleAdmin],
    ),

    // --- SHARED INTENTS ---
    ChatIntent(
      keywords: ['privacy', 'dpa', 'data', 'ra 10173', 'terms'],
      response:
          "We strictly adhere to the Data Privacy Act (RA 10173). Your data is only used for fulfilling your motorcycle plate orders and generating your personal QR code.",
      allowedRoles: [
        AppConstants.roleCustomer,
        AppConstants.roleStaff,
        AppConstants.roleAdmin
      ],
    ),
    ChatIntent(
      keywords: ['legal', 'lto', 'ticket', 'law', 'police'],
      response: ChatbotKnowledge.legalRefusalResponse,
      allowedRoles: [
        AppConstants.roleCustomer,
        AppConstants.roleStaff,
        AppConstants.roleAdmin
      ],
    ),
  ];
}
