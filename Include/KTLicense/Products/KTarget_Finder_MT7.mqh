#ifndef KTARGET_FINDER_MT7_LICENSE_MQH
#define KTARGET_FINDER_MT7_LICENSE_MQH

#include <KTLicense/KT_License.mqh>

#define KTARGET_FINDER_MT7_PRODUCT_ID   "KTARGET_FINDER_MT7"
#define KTARGET_FINDER_MT7_PRODUCT_NAME "KTarget Finder MT7"
#define KTARGET_FINDER_MT7_KEY_ID       "KT-FINDER-MT7-V1"

bool KTargetFinderMt7LicenseInitialize()
{
   uchar productKey[] =
   {
      0x8a, 0x3f, 0x71, 0xc4, 0x16, 0xd9, 0x2e, 0xb7,
      0x54, 0x0c, 0xe8, 0x93, 0x6a, 0xf1, 0x45, 0x2d,
      0xb0, 0x67, 0x19, 0xde, 0x82, 0x3b, 0xfa, 0x50,
      0xcd, 0x24, 0x9e, 0x78, 0x41, 0xab, 0x05, 0xf6
   };

   return KTLicenseInitialize(KTARGET_FINDER_MT7_PRODUCT_ID,
                              KTARGET_FINDER_MT7_PRODUCT_NAME,
                              KTARGET_FINDER_MT7_KEY_ID,
                              productKey);
}

#endif