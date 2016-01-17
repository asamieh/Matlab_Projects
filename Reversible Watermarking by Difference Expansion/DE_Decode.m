function [WATERMARK_PAYLOAD, ORG_IMAGE] = DE_Decode(WATERMARKED_IMAGE)

    [HEIGHT WIDTH] = size(WATERMARKED_IMAGE);
    WM_IMAGE_DIFF = blkproc(double(WATERMARKED_IMAGE), [1 2], inline('x(1) - x(2)')); % get difference
    WM_IMAGE_AVRG = blkproc(double(WATERMARKED_IMAGE), [1 2], inline('floor((x(1) + x(2)) / 2)')); % get average

    WM_CN_SET_Index  = 1;
    for i = 1 : HEIGHT
        for j = 1 : WIDTH / 2
            if abs(2 * floor(WM_IMAGE_DIFF(i, j) / 2) + 0) <= min(2 * (255 - WM_IMAGE_AVRG(i, j)), 2 * WM_IMAGE_AVRG(i, j) + 1)...
                 || abs(2 * floor(WM_IMAGE_DIFF(i, j) / 2) + 1) <= min(2 * (255 - WM_IMAGE_AVRG(i, j)), 2 * WM_IMAGE_AVRG(i, j) + 1)
                WM_CN_SET_LSBs(WM_CN_SET_Index) = bitget(abs(WM_IMAGE_DIFF(i, j)), 1);
                WM_CN_SET_Index = WM_CN_SET_Index + 1;
            end
        end
    end
    for i = 1 : length(WM_CN_SET_LSBs)
        payload_str(i) = num2str(WM_CN_SET_LSBs(i));
    end
    LOCAL_MAP_VECTOR_COUNTS(1, 1)   = bin2dec(payload_str( 1 :   8));
    LOCAL_MAP_VECTOR_COUNTS(1, 2)   = bin2dec(payload_str( 9 :  16));
    EN2_CN_LSBs_COUNTS(1, 1)        = bin2dec(payload_str(17 :  24));
    EN2_CN_LSBs_COUNTS(1, 2)        = bin2dec(payload_str(25 :  32));
    LOCAL_MAP_VECTOR_LENGTH         = bin2dec(payload_str(33 :  48));
    LOCAL_MAP_VECTOR_ENCODED_LENGTH = bin2dec(payload_str(49 :  64));
    EN2_CN_LSBs_LENGTH              = bin2dec(payload_str(65 :  80));
    EN2_CN_LSBs_ENCODED_LENGTH      = bin2dec(payload_str(81 :  96));
    WATERMARK_LENGTH                = bin2dec(payload_str(97 : 112));
    LOCAL_MAP_VECTOR_ENCODED        = WM_CN_SET_LSBs(113 : 112 + LOCAL_MAP_VECTOR_ENCODED_LENGTH);
    EN2_CN_LSBs_ENCODED             = WM_CN_SET_LSBs(113 + LOCAL_MAP_VECTOR_ENCODED_LENGTH : 112 + LOCAL_MAP_VECTOR_ENCODED_LENGTH + EN2_CN_LSBs_ENCODED_LENGTH);
    WATERMARK_PAYLOAD               = WM_CN_SET_LSBs(113 + LOCAL_MAP_VECTOR_ENCODED_LENGTH + EN2_CN_LSBs_ENCODED_LENGTH : 112 + LOCAL_MAP_VECTOR_ENCODED_LENGTH + EN2_CN_LSBs_ENCODED_LENGTH + WATERMARK_LENGTH);
    LOCAL_MAP_VECTOR                = arithdeco(LOCAL_MAP_VECTOR_ENCODED, LOCAL_MAP_VECTOR_COUNTS, LOCAL_MAP_VECTOR_LENGTH);
    LOCAL_MAP_VECTOR                = LOCAL_MAP_VECTOR - 1;
    LOCAL_MAP_ARRAY                 = reshape(LOCAL_MAP_VECTOR, HEIGHT, WIDTH / 2);
    EN2_CN_LSBs                     = arithdeco(EN2_CN_LSBs_ENCODED, EN2_CN_LSBs_COUNTS, EN2_CN_LSBs_LENGTH);
    EN2_CN_LSBs                     = EN2_CN_LSBs - 1;
    ORG_IMAGE                       = zeros(HEIGHT, WIDTH);
    % last step - has issue
    EN2_CN_LSBs_Index  = 1;
    for i = 1 : HEIGHT
        ORG_Index = 1;
        for j = 1 : WIDTH / 2
            if abs(2 * floor(WM_IMAGE_DIFF(i, j) / 2) + 0) <= min(2 * (255 - WM_IMAGE_AVRG(i, j)), 2 * WM_IMAGE_AVRG(i, j) + 1)...
                 || abs(2 * floor(WM_IMAGE_DIFF(i, j) / 2) + 1) <= min(2 * (255 - WM_IMAGE_AVRG(i, j)), 2 * WM_IMAGE_AVRG(i, j) + 1)
                if LOCAL_MAP_ARRAY(i, j) == 1
                    if WM_IMAGE_DIFF(i, j) < 0
                        sign = -1;
                    else
                        sign = 1;
                    end
                    WM_IMAGE_DIFF(i, j) = sign * floor((abs(WM_IMAGE_DIFF(i, j)) / 2));
                else
                    if WM_IMAGE_DIFF(i, j) < 0
                        sign = -1;
                    else
                        sign = 1;
                    end
                    WM_IMAGE_DIFF(i, j) = sign * (2 * floor(abs(WM_IMAGE_DIFF(i, j)) / 2) + EN2_CN_LSBs(EN2_CN_LSBs_Index));
                    EN2_CN_LSBs_Index = EN2_CN_LSBs_Index + 1;
                end
            end
            ORG_IMAGE(i, ORG_Index)     = WM_IMAGE_AVRG(i, j) + floor(((WM_IMAGE_DIFF(i, j) + 1) / 2));
            ORG_IMAGE(i, ORG_Index + 1) = WM_IMAGE_AVRG(i, j) - floor(WM_IMAGE_DIFF(i, j) / 2);
            ORG_Index = ORG_Index + 2;
        end
    end

