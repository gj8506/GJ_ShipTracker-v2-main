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
      "I'm your virtual guide, but I didn't quite catch that. Try using one of the quick replies below, or ask me about orders, dispatching, or privacy!";

  static const String legalRefusalResponse =
      "I cannot provide legal advice regarding the LTO compliance of temporary plates. Please consult official local transportation guidelines.";

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
