Shader "PinkRammy/Unlit/NumberDisplay"
{
    Properties
    {
        _BackgroundColor ("Background Color", Color) = (0, 0, 0, 1)
        _ValueColor ("Value Color", Color) = (1, 1, 1, 1)
        _Value ("Value (0.0 - 0.9999)", Range(0, 1)) = 0.1337
        [Toggle] _SameCellSize ("Digits Same Size", float) = 0.0
        [Toggle] _DigitPadding ("0 padding", float) = 0.0
        [Toggle] _DrawCurrencyMarker ("Draws the currency marker", float) = 0.0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
	            UNITY_INITIALIZE_OUTPUT(v2f, o);
	            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                return o;
            }

            fixed4 _BackgroundColor;
            fixed4 _ValueColor;
            float _Value;
            fixed _SameCellSize;
            fixed _DigitPadding;
            fixed _DrawCurrencyMarker;

            /*
            ** Digits are 5 x 7 (5 wide, 7 tall) and can be encoded with binary
            ** We would need 35 bits and that means we have to split the encoding since we can only fit 32 in an int
            ** We can append 0 to the end and it will be discarded when querying so we have a 36-bit encoding with
            ** two groups 1 x 16, 1 x 20
            ** =============================================================================================================================================
            **  . 1 1 1 .    . . 1 . .    . 1 1 1 .    . 1 1 1 .    . . . 1 1    1 1 1 1 1    . . 1 1 .    1 1 1 1 1    . 1 1 1 .    . 1 1 1 .    . . . . . 
            **  1 . . . 1    . 1 1 . .    1 . . . 1    1 . . . 1    . . 1 . 1    1 . . . .    . 1 . . .    . . . . 1    1 . . . 1    1 . . . 1    . . 1 . .
            **  1 . . 1 1    . . 1 . .    . . . . 1    . . . . 1    . 1 . . 1    1 . . . .    1 . . . .    . . . 1 .    1 . . . 1    1 . . . 1    . 1 1 1 .
            **  1 . 1 . 1    . . 1 . .    . . . 1 .    . . 1 1 .    1 . . . 1    1 1 1 1 .    1 1 1 1 .    . . 1 . .    . 1 1 1 .    . 1 1 1 1    1 . 1 . .
            **  1 1 . . 1    . . 1 . .    . . 1 . .    . . . . 1    1 1 1 1 1    . . . . 1    1 . . . 1    . . 1 . .    1 . . . 1    . . . 1 .    1 . 1 . .
            **  1 . . . 1    . . 1 . .    . 1 . . .    1 . . . 1    . . . . 1    . . . . 1    1 . . . 1    . . 1 . .    1 . . . 1    . . 1 . .    . 1 1 1 .
            **  . 1 1 1 .    . 1 1 1 .    1 1 1 1 1    . 1 1 1 .    . . . . 1    1 1 1 1 .    . 1 1 1 .    . . 1 . .    . 1 1 1 .    . 1 . . .    . . 1 . .
            **  ============================================================================================================================================
            ** 0 = 01110 10001 10011 10101 11001 10001 01110 => 01110100011001110101110011000101110+0 => 0x7467 & 0x5CC5C
            ** 1 = 00100 01100 00100 00100 00100 00100 01110 => 00100011000010000100001000010001110+0 => 0x2308 & 0x4211C
            ** 2 = 01110 10001 00001 00010 00100 01000 11111 => 01110100010000100010001000100011111+0 => 0x7442 & 0x2223E
            ** 3 = 01110 10001 00001 00110 00001 10001 01110 => 01110100010000100110000011000101110+0 => 0x7442 & 0x60C5C
            ** 4 = 00011 00101 01001 10001 11111 00001 00001 => 00011001010100110001111110000100001+0 => 0x1953 & 0x1F842
            ** 5 = 11111 10000 10000 11110 00001 00001 11110 => 11111100001000011110000010000111110+0 => 0xFC21 & 0xE087C
            ** 6 = 00110 01000 10000 11110 10001 10001 01110 => 00110010001000011110100011000101110+0 => 0x3221 & 0xE8C5C
            ** 7 = 11111 00001 00010 00100 00100 00100 00100 => 11111000010001000100001000010000100+0 => 0xF844 & 0x42108
            ** 8 = 01110 10001 10001 01110 10001 10001 01110 => 01110100011000101110100011000101110+0 => 0x7462 & 0xE8C5C
            ** 9 = 01110 10001 10001 01111 00010 00100 01000 => 01110100011000101111000100010001000+0 => 0x7462 & 0xF1110
            ** C = 00000 00100 01110 10100 10100 01110 00100 => 00000001000111010100101000111000100+0 => 0x011D & 0x4A388
            */
            #define DigitNull uint2(0, 0)
            #define Digit0 uint2(0x7467, 0x5CC5C)
            #define Digit1 uint2(0x2308, 0x4211C)
            #define Digit2 uint2(0x7442, 0x2223E)
            #define Digit3 uint2(0x7442, 0x60C5C)
            #define Digit4 uint2(0x1953, 0x1F842)
            #define Digit5 uint2(0xFC21, 0xE087C)
            #define Digit6 uint2(0x3221, 0xE8C5C)
            #define Digit7 uint2(0xF844, 0x42108)
            #define Digit8 uint2(0x7462, 0xE8C5C)
            #define Digit9 uint2(0x7462, 0xF1110)
            #define Currency uint2(0x011D, 0x4A388)

            struct Digit {
                uint2 pixels;
                float4 bounds;
                float cellSize;

                uint getCellColor(uint index)
                {
                    uint cellIndex = index < 16 ? 15 - index : 19 - (index - 16);
                    return (index < 16 ? (pixels.x >> cellIndex) : (pixels.y >> cellIndex)) & 1;
                }

                bool inBounds(float2 uv, uint index)
                {
                    bool inDigitBounds = uv.x > bounds.x && uv.x < bounds.z && uv.y > bounds.y && uv.y < bounds.w;
                    if (!inDigitBounds) return false;

                    uint row = index / 5;
                    uint column = index % 5;

                    float cellMinX = bounds.x + cellSize * column;
                    float cellMaxX = cellMinX + cellSize;
                    float cellMinY = bounds.w - cellSize * (row + 1);
                    float cellMaxY = cellMinY + cellSize;
                    return uv.x > cellMinX && uv.x < cellMaxX && uv.y > cellMinY && uv.y < cellMaxY;
                }
            };

            float4 getDigitBounds(float2 center, float cellSize)
            { 
                float cellDeltaX = cellSize * 2 + cellSize / 2;
                float cellDeltaY = cellSize * 3 + cellSize / 2;
                float minX = center.x - cellDeltaX;
                float minY = center.y - cellDeltaY;
                float maxX = center.x + cellDeltaX;
                float maxY = center.y + cellDeltaY;
                return float4(minX, minY, maxX, maxY);
            }

            uint2 getDigitPixels(uint value)
            {
                switch (value)
                {
                    case 0: return Digit0;
                    case 1: return Digit1;
                    case 2: return Digit2;
                    case 3: return Digit3;
                    case 4: return Digit4;
                    case 5: return Digit5;
                    case 6: return Digit6;
                    case 7: return Digit7;
                    case 8: return Digit8;
                    case 9: return Digit9;
                    case 10: return Currency;
                    default: return DigitNull;
                }
            }

            Digit getDigit(uint value, float2 center, float cellSize) {
                if (value < 0 || value > 10)
                {
                    value = 0;
                }

                Digit digit;
                digit.pixels = getDigitPixels(value);
                digit.cellSize = cellSize;
                digit.bounds = getDigitBounds(center, cellSize);
                return digit;
            }

            float drawDigitCell(float2 uv, Digit digit, uint cellIndex)
            {
                if (!digit.inBounds(uv, cellIndex)) return 0.0;
                return digit.getCellColor(cellIndex);
            }

            float drawDigit(float2 uv, float2 center, float cellSize, uint digitValue)
            {
                Digit digit = getDigit(digitValue, center, cellSize);

                float result = 0.0;
                float cellIndex = 0;
                for (int row = 0; row < 7; row++)
                {
                    for(int col = 0; col < 5; col++)
                    {
                        result += drawDigitCell(uv, digit, cellIndex);
                        cellIndex++;
                    }
                }

                return result;
            }

            uint getNumberDigits(float value)
            {
                if (value >= 1000.0) return 4;
                if (value >= 100.0) return 3;
                if (value >= 10.0) return 2;
                return 1;
            }

            uint getNumberDigit(uint number, int digitIndex)
            {
                if (number < 10) return number;
                if (number < 100 && digitIndex < 2)
                {
                    float2 digits = float2(
                        number / 10,
                        number % 10
                    );
                    return digits[digitIndex];
                }

                if (number < 1000 && digitIndex < 3)
                {
                    float3 digits = float3(
                        number / 100,
                        (number / 10) % 10,
                        number % 10
                    );
                    return digits[digitIndex];
                }

                float4 digits = float4(
                    uint(number / 1000),
                    (number / 100) % 10,
                    (number / 10) % 10,
                    number % 10
                );
                return digits[digitIndex];
            }

            float4 getDigitCoords(uint digits, bool currencyMarker)
            {
                // For 1 digit, we draw in the center
                // If the currency marker is shown, we draw in a UV space split in half
                if (digits == 1)
                {
                    return currencyMarker ?
                        float4(0.3, 0.7, 0.0, 0.0) :
                        float4(0.5, 0.0, 0.0, 0.0);
                }

                // For 2 digits, we draw in a UV space split in half
                // If the currency marker is shown, we draw in a UV space split in three
                if (digits == 2)
                {
                    return currencyMarker ?
                        float4(0.25, 0.5, 0.75, 0.0) :
                        float4(0.3, 0.7, 0.0, 0.0);
                }

                // For 3 digits, we draw in a UV space split in three
                // If the currency marker is shown, we draw in a UV space split in four
                if (digits == 3)
                {
                    return currencyMarker ?
                        float4(0.2, 0.4, 0.6, 0.8) :
                        float4(0.25, 0.5, 0.75, 0.0);
                }

                // For 4 digits, we draw in a UV space split in four
                // If the currency marker is shown, we draw in a UV space split in five (but return the first four coords)
                return currencyMarker ?
                    float4(0.17, 0.34, 0.51, 0.68) :
                    float4(0.2, 0.4, 0.6, 0.8);
            }

            float2 getCurrencyMarkerCoords(uint digits)
            {
                if (digits == 1) return float2(0.7, 0.5);
                if (digits == 2) return float2(0.75, 0.5);
                if (digits == 3) return float2(0.8, 0.5);
                return float2(0.85, 0.5);
            }

            float getDigitCenterX(uint digits, uint index)
            {
                bool currencyMarker = _DrawCurrencyMarker == 1.0;
                if (_DigitPadding == 1.0)
                {
                    return getDigitCoords(4, currencyMarker)[index];
                }

                float4 digitCoords = getDigitCoords(digits, currencyMarker);

                if (digits == 1 || index >= digits)
                {
                    return digitCoords[0];
                }

                if (digits == 2)
                {
                    float4 values = _SameCellSize == 1.0 ?
                        float4(0.4, 0.6, 0.0, 0.0) :
                        digitCoords;
                    return values[index];
                }

                if (digits == 3)
                {
                    float3 values = _SameCellSize == 1.0 ?
                        float4(0.3, 0.5, 0.7, 0.0) :
                        digitCoords;
                    return values[index];
                }

                return digitCoords[index];
            }

            float drawNumber(float2 uv, uint value)
            {
                int digits = getNumberDigits(value);
                int paddedDigits = _DigitPadding == 1.0 ? 4 : digits;
                int zeroCount = paddedDigits - digits;

                bool digitsSameSize = _SameCellSize == 1.0 || _DigitPadding == 1.0;

                float digitsCount = _DrawCurrencyMarker == 1.0 ? digits + 1 : digits;
                float cellSize = digitsSameSize ? 0.025 : 0.1 / digitsCount;
                float result = 0.0;

                for (int i = 0; i < paddedDigits; i++)
                {
                    uint digitToDraw = i < zeroCount ? 0 : getNumberDigit(value, i - zeroCount);
                    float2 digitCenter = float2(
                        getDigitCenterX(digits, i),
                        0.5
                    );
                    result += drawDigit(uv, digitCenter, cellSize, digitToDraw);
                }

                if (_DrawCurrencyMarker == 1.0)
                {
                    float2 currencyCenter = getCurrencyMarkerCoords(paddedDigits);
                    result += drawDigit(uv, currencyCenter, cellSize, 10);
                }

                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                uint value = _Value * 10000;
                uint number = clamp(value, 0, 9999);
                return lerp(_BackgroundColor, _ValueColor, drawNumber(i.uv, number));
            }
            ENDCG
        }
    }
}
