#ifndef KT_LICENSE_MQH
#define KT_LICENSE_MQH

#include <KTLicense/KT_License_Types.mqh>
#include <KTLicense/KT_Author_Info.mqh>

#define KT_LICENSE_DEFAULT_FILE "KTLicense\\license.dat"
#define KT_LICENSE_EXPIRY_WARNING_DAYS 30

KT_LICENSE_STATUS g_ktLicenseStatus = KT_LICENSE_NOT_CHECKED;
KTLicenseData g_ktLicenseData;
string g_ktLicenseMessage = "License has not been checked";

void KTLicenseSetResult(KT_LICENSE_STATUS status, string message)
{
   g_ktLicenseStatus = status;
   g_ktLicenseMessage = message;
}

bool KTLicenseIsDecimal(string value)
{
   int length = StringLen(value);
   if(length <= 0)
      return false;

   for(int i = 0; i < length; i++)
   {
      ushort character = StringGetCharacter(value, i);
      if(character < '0' || character > '9')
         return false;
   }

   return true;
}

bool KTLicenseContainsToken(string list, string token)
{
   string items[];
   int count = StringSplit(list, '|', items);

   for(int i = 0; i < count; i++)
   {
      if(items[i] == token)
         return true;
   }

   return false;
}

bool KTLicenseFindProductSignature(string signatures,
                                   string productId,
                                   string expectedKeyId,
                                   string &mac)
{
   string entries[];
   int entryCount = StringSplit(signatures, '|', entries);

   for(int i = 0; i < entryCount; i++)
   {
      string parts[];
      if(StringSplit(entries[i], '@', parts) != 3)
         return false;

      if(parts[0] == productId && parts[1] == expectedKeyId)
      {
         mac = parts[2];
         return true;
      }
   }

   return false;
}

bool KTLicenseStringToUtf8(string value, uchar &bytes[])
{
   int count = StringToCharArray(value, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   if(count <= 0)
      return false;

   ArrayResize(bytes, count - 1);
   return true;
}

bool KTLicenseSha256(const uchar &data[], uchar &digest[])
{
   uchar emptyKey[];
   ArrayResize(emptyKey, 0);
   ArrayResize(digest, 0);
   ResetLastError();
   int result = CryptEncode(CRYPT_HASH_SHA256, data, emptyKey, digest);
   return (result == 32 && ArraySize(digest) == 32);
}

bool KTLicenseHmacSha256(string message, const uchar &key[], uchar &mac[])
{
   const int blockSize = 64;
   uchar normalizedKey[];
   uchar keyHash[];
   int keySize = ArraySize(key);

   ArrayResize(normalizedKey, blockSize);
   ArrayInitialize(normalizedKey, 0);

   if(keySize > blockSize)
   {
      if(!KTLicenseSha256(key, keyHash))
         return false;
      ArrayCopy(normalizedKey, keyHash, 0, 0, ArraySize(keyHash));
   }
   else
   {
      ArrayCopy(normalizedKey, key, 0, 0, keySize);
   }

   uchar innerPad[];
   uchar outerPad[];
   ArrayResize(innerPad, blockSize);
   ArrayResize(outerPad, blockSize);

   for(int i = 0; i < blockSize; i++)
   {
      innerPad[i] = (uchar)(normalizedKey[i] ^ 0x36);
      outerPad[i] = (uchar)(normalizedKey[i] ^ 0x5c);
   }

   uchar messageBytes[];
   if(!KTLicenseStringToUtf8(message, messageBytes))
      return false;

   uchar innerData[];
   ArrayResize(innerData, blockSize + ArraySize(messageBytes));
   ArrayCopy(innerData, innerPad, 0, 0, blockSize);
   ArrayCopy(innerData, messageBytes, blockSize, 0, ArraySize(messageBytes));

   uchar innerHash[];
   if(!KTLicenseSha256(innerData, innerHash))
      return false;

   uchar outerData[];
   ArrayResize(outerData, blockSize + ArraySize(innerHash));
   ArrayCopy(outerData, outerPad, 0, 0, blockSize);
   ArrayCopy(outerData, innerHash, blockSize, 0, ArraySize(innerHash));

   return KTLicenseSha256(outerData, mac);
}

string KTLicenseBytesToHex(const uchar &bytes[])
{
   string alphabet = "0123456789abcdef";
   string result = "";

   for(int i = 0; i < ArraySize(bytes); i++)
   {
      result += StringSubstr(alphabet, bytes[i] >> 4, 1);
      result += StringSubstr(alphabet, bytes[i] & 15, 1);
   }

   return result;
}

bool KTLicenseSecureEquals(string left, string right)
{
   if(StringLen(left) != StringLen(right))
      return false;

   int difference = 0;
   for(int i = 0; i < StringLen(left); i++)
      difference |= StringGetCharacter(left, i) ^ StringGetCharacter(right, i);

   return (difference == 0);
}

string KTLicenseCanonicalText(const KTLicenseData &license)
{
   return "schema=" + IntegerToString(license.schema) + "\n" +
          "license_id=" + license.license_id + "\n" +
          "customer_id=" + license.customer_id + "\n" +
          "issued_at=" + IntegerToString((long)license.issued_at) + "\n" +
          "not_before=" + IntegerToString((long)license.not_before) + "\n" +
          "expires_at=" + IntegerToString((long)license.expires_at) + "\n" +
          "accounts=" + license.accounts + "\n" +
          "products=" + license.products + "\n" +
          "edition=" + license.edition;
}

bool KTLicenseAssignField(KTLicenseData &license, string key, string value)
{
   if(key == "schema" && license.schema == 0 && KTLicenseIsDecimal(value))
      license.schema = (int)StringToInteger(value);
   else if(key == "license_id" && license.license_id == "")
      license.license_id = value;
   else if(key == "customer_id" && license.customer_id == "")
      license.customer_id = value;
   else if(key == "issued_at" && license.issued_at == 0 && KTLicenseIsDecimal(value))
      license.issued_at = (datetime)StringToInteger(value);
   else if(key == "not_before" && license.not_before == 0 && KTLicenseIsDecimal(value))
      license.not_before = (datetime)StringToInteger(value);
   else if(key == "expires_at" && license.expires_at == 0 && KTLicenseIsDecimal(value))
      license.expires_at = (datetime)StringToInteger(value);
   else if(key == "accounts" && license.accounts == "")
      license.accounts = value;
   else if(key == "products" && license.products == "")
      license.products = value;
   else if(key == "edition" && license.edition == "")
      license.edition = value;
   else if(key == "signatures" && license.signatures == "")
      license.signatures = value;
   else
      return false;

   return (value != "");
}

bool KTLicenseLoad(string fileName, KTLicenseData &license)
{
   license.schema = 0;
   license.license_id = "";
   license.customer_id = "";
   license.issued_at = 0;
   license.not_before = 0;
   license.expires_at = 0;
   license.accounts = "";
   license.products = "";
   license.edition = "";
   license.signatures = "";

   ResetLastError();
   int handle = FileOpen(fileName, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(handle == INVALID_HANDLE)
   {
      KTLicenseSetResult(KT_LICENSE_FILE_NOT_FOUND,
                         "License file not found: Common\\Files\\" + fileName);
      return false;
   }

   int fieldCount = 0;
   bool valid = true;

   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(line == "")
         continue;

      int separator = StringFind(line, "=");
      if(separator <= 0)
      {
         valid = false;
         break;
      }

      string key = StringSubstr(line, 0, separator);
      string value = StringSubstr(line, separator + 1);
      if(!KTLicenseAssignField(license, key, value))
      {
         valid = false;
         break;
      }

      fieldCount++;
   }

   FileClose(handle);

   if(!valid || fieldCount != 10 || license.schema != 1 ||
      license.issued_at <= 0 || license.not_before <= 0 || license.expires_at <= 0)
   {
      KTLicenseSetResult(KT_LICENSE_FILE_INVALID, "License file format is invalid");
      return false;
   }

   return true;
}

bool KTLicenseInitialize(string productId,
                         string productName,
                         string expectedKeyId,
                         const uchar &productKey[],
                         string fileName = KT_LICENSE_DEFAULT_FILE)
{
   KTLicenseData license;
   if(!KTLicenseLoad(fileName, license))
      return false;

   string actualMac = "";
   if(!KTLicenseFindProductSignature(license.signatures, productId, expectedKeyId, actualMac))
   {
      KTLicenseSetResult(KT_LICENSE_KEY_MISMATCH,
                         "License does not contain a compatible signature for this product build");
      return false;
   }

   uchar computedMac[];
   if(!KTLicenseHmacSha256(KTLicenseCanonicalText(license), productKey, computedMac))
   {
      KTLicenseSetResult(KT_LICENSE_CRYPTO_ERROR, "Unable to calculate the license signature");
      return false;
   }

   string expectedMac = KTLicenseBytesToHex(computedMac);
   StringToLower(actualMac);
   if(!KTLicenseSecureEquals(expectedMac, actualMac))
   {
      KTLicenseSetResult(KT_LICENSE_SIGNATURE_INVALID, "License signature is invalid");
      return false;
   }

   datetime trustedNow = (datetime)MathMax((long)TimeCurrent(), (long)TimeGMT());
   if(trustedNow < license.not_before)
   {
      KTLicenseSetResult(KT_LICENSE_NOT_YET_VALID, "License is not active yet");
      return false;
   }

   if(trustedNow > license.expires_at)
   {
      KTLicenseSetResult(KT_LICENSE_EXPIRED, "License has expired");
      return false;
   }

   // MQL5 exposes account identity through AccountInfo* instead of the
   // MQL4 AccountNumber/AccountServer helpers.
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string accountServer = AccountInfoString(ACCOUNT_SERVER);
   if(accountNumber <= 0 || StringLen(accountServer) == 0)
   {
      KTLicenseSetResult(KT_LICENSE_WAITING_FOR_ACCOUNT,
                         "Waiting for MT5 account connection");
      return false;
   }

   string accountToken = IntegerToString(accountNumber) + "@" + accountServer;
   if(!KTLicenseContainsToken(license.accounts, accountToken))
   {
      KTLicenseSetResult(KT_LICENSE_ACCOUNT_MISMATCH,
                         "This trading account is not licensed: " + accountToken);
      return false;
   }

   if(!KTLicenseContainsToken(license.products, productId))
   {
      KTLicenseSetResult(KT_LICENSE_PRODUCT_DENIED, "This product is not included in the license");
      return false;
   }

   g_ktLicenseData = license;
   KTLicenseSetResult(KT_LICENSE_OK, "License is valid");
      Print("[KT License] Authorized: product=", productId,
         ", name=", productName,
         ", license=", license.license_id,
         ", expires=", TimeToString(license.expires_at, TIME_DATE | TIME_SECONDS),
         " UTC, ", KT_AUTHOR_CONTACT_TEXT);

   int remainingDays = (int)((license.expires_at - trustedNow) / 86400);
   if(remainingDays >= 0 && remainingDays <= KT_LICENSE_EXPIRY_WARNING_DAYS)
   {
      string expiryMessage = productName + " license expires in " +
                             IntegerToString(remainingDays) + " day(s)." +
                             KTAuthorContactMessage();
      Print("[KT License] ", expiryMessage);
      Alert(expiryMessage);
   }
   return true;
}

bool KTLicenseCanStart()
{
   return (g_ktLicenseStatus == KT_LICENSE_OK);
}

bool KTLicenseIsWaitingForAccount()
{
   return (g_ktLicenseStatus == KT_LICENSE_WAITING_FOR_ACCOUNT);
}

KT_LICENSE_STATUS KTLicenseGetStatus()
{
   return g_ktLicenseStatus;
}

string KTLicenseGetMessage()
{
   return g_ktLicenseMessage + KTAuthorContactMessage();
}

datetime KTLicenseGetExpiry()
{
   return g_ktLicenseData.expires_at;
}

string KTLicenseGetLicenseId()
{
   return g_ktLicenseData.license_id;
}

#endif