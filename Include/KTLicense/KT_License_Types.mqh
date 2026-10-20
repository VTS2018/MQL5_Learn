#ifndef KT_LICENSE_TYPES_MQH
#define KT_LICENSE_TYPES_MQH

enum KT_LICENSE_STATUS
{
   KT_LICENSE_NOT_CHECKED = 0,
   KT_LICENSE_OK,
   KT_LICENSE_FILE_NOT_FOUND,
   KT_LICENSE_FILE_INVALID,
   KT_LICENSE_SIGNATURE_INVALID,
   KT_LICENSE_NOT_YET_VALID,
   KT_LICENSE_EXPIRED,
   KT_LICENSE_ACCOUNT_MISMATCH,
   KT_LICENSE_PRODUCT_DENIED,
   KT_LICENSE_KEY_MISMATCH,
   KT_LICENSE_CRYPTO_ERROR,
   KT_LICENSE_WAITING_FOR_ACCOUNT
};

struct KTLicenseData
{
   int schema;
   string license_id;
   string customer_id;
   datetime issued_at;
   datetime not_before;
   datetime expires_at;
   string accounts;
   string products;
   string edition;
   string signatures;
};

#endif