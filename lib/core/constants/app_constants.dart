class AppConstants {
  // Brand Assets
  static const String appName = 'GJ and Asher Digital Printing';
  static const String appSubtitle = 'ShipTracker - Outbound & Returns';
  static const String logoAsset = 'assets/images/GJandAsher_logo.jpg';

  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'zxatyaly';
  static const String cloudinaryUploadPreset = 'shiptracker_returns';

  // Firestore Collections
  static const String collectionParcels = 'parcels';
  static const String collectionReturns = 'returns';
  static const String collectionUsers = 'users';
  static const String collectionCustomers = 'customers';

  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleStaff = 'staff';
  static const String roleCustomer = 'customer';

  // Platforms
  static const String platformShopee = 'Shopee';
  static const String platformLazada = 'Lazada';
  static const String platformTikTok = 'TikTok';
  static const String platformDirect = 'Direct / Walk-in';

  static const List<String> allPlatforms = [
    platformShopee,
    platformLazada,
    platformTikTok,
    platformDirect,
  ];

  static const List<String> supportedPlatforms = allPlatforms;

  // Couriers
  static const String courierJT = 'J&T Express';
  static const String courierFlash = 'Flash Express';
  static const String courierSPX = 'SPX Express';
  static const String courierLBC = 'LBC Express';
  static const String courierNinjaVan = 'Ninja Van';

  static const List<String> supportedCouriers = [
    courierJT,
    courierFlash,
    courierSPX,
    courierLBC,
    courierNinjaVan,
  ];

  static const List<String> allCouriers = supportedCouriers;

  // Parcel Logistics Statuses
  static const String statusPending = 'Pending';
  static const String statusPrinted = 'Printed';
  static const String statusPacked = 'Packed';
  static const String statusDispatched = 'Dispatched';
  static const String statusInTransit = 'In Transit';
  static const String statusDelivered = 'Delivered';
  static const String statusCancelled = 'Cancelled';
  static const String statusReturned = 'Returned';

  static const List<String> allParcelStatuses = [
    statusPending,
    statusPrinted,
    statusPacked,
    statusDispatched,
    statusInTransit,
    statusDelivered,
    statusCancelled,
    statusReturned,
  ];

  static const List<String> parcelStatuses = allParcelStatuses;

  // Customer Types
  static const String customerTypeRegular = 'Regular';
  static const String customerTypeReseller = 'Reseller';

  static const List<String> customerTypes = [
    customerTypeRegular,
    customerTypeReseller,
  ];

  // Return Defect Reasons
  static const String defectDamaged = 'Damaged in Transit';
  static const String defectWrongItem = 'Wrong Plate/Design';
  static const String defectPrintingError = 'Printing Error/Blurry';
  static const String defectMissingItem = 'Missing Item';
  static const String defectCustomerChange = 'Customer Changed Mind';

  static const List<String> returnDefectReasons = [
    defectDamaged,
    defectWrongItem,
    defectPrintingError,
    defectMissingItem,
    defectCustomerChange,
  ];

  // Return Statuses
  static const String returnStatusPending = 'Pending Review';
  static const String returnStatusApproved = 'Approved';
  static const String returnStatusReplacementDispatched =
      'Replacement Dispatched';
  static const String returnStatusRefunded = 'Refunded';
  static const String returnStatusRejected = 'Rejected';

  static const List<String> returnStatuses = [
    returnStatusPending,
    returnStatusApproved,
    returnStatusReplacementDispatched,
    returnStatusRefunded,
    returnStatusRejected,
  ];
}
