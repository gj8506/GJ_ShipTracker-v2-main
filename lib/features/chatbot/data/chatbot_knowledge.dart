import '../../../core/constants/app_constants.dart';

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
  static const List<String> dataRequestKeywords = [
    'how many orders',
    'how many parcels',
    'how many customers',
    'number of orders',
    'number of parcels',
    'number of customers',
    'list of orders',
    'list of parcels',
    'list of customers',
    'all orders',
    'all parcels',
    'all customers',
    'show me the orders',
    'show me the parcels',
    'show me the customers',
    'show me all',
    'customer list',
    'order list',
    'parcel list',
    'database',
    'firestore',
    'firebase',
    'records',
    'query the',
    'look up order',
    'look up parcel',
    'look up customer',
    'find order',
    'find parcel',
    'find customer',
    'who ordered',
    'total sales',
    'total revenue',
    'sales today',
    'revenue today',
    'earnings today',
    'address of',
    'phone number of',
    'contact number of',
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
