#ifndef KT_DRAWING_TOOL_V2_LICENSE_MQH
#define KT_DRAWING_TOOL_V2_LICENSE_MQH

#include <KTLicense/KT_License.mqh>

#define KT_DRAWING_TOOL_V2_PRODUCT_ID "KT_DRAWING_TOOL_V2"
#define KT_DRAWING_TOOL_V2_PRODUCT_NAME "KT Drawing Tool V2"
#define KT_DRAWING_TOOL_V2_KEY_ID     "KT-DRAW-V1"

bool KTDrawingToolLicenseInitialize()
{
   uchar productKey[] =
   {
      0x24, 0xd7, 0x00, 0xe6, 0xb7, 0x10, 0x67, 0xc9,
      0xaf, 0xb1, 0xb3, 0xe8, 0xfb, 0x0c, 0x45, 0x29,
      0xfa, 0x11, 0x3c, 0xcf, 0x8c, 0x13, 0xd9, 0x39,
      0x46, 0x58, 0xcc, 0x50, 0x7e, 0x24, 0xe5, 0x8a
   };

   return KTLicenseInitialize(KT_DRAWING_TOOL_V2_PRODUCT_ID,
                              KT_DRAWING_TOOL_V2_PRODUCT_NAME,
                              KT_DRAWING_TOOL_V2_KEY_ID,
                              productKey);
}

#endif