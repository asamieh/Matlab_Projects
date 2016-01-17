function [WATERMARKED_IMAGE] = DE_Encode(ORIGINAL_IMAGE, WATERMARK_PAYLOAD)
    THRESHOLD = 20;
    [HEIGHT WIDTH] = size(ORIGINAL_IMAGE);
    WATERMARK_LENGTH = length(WATERMARK_PAYLOAD);
    %% STEP 1 : calculating the difference values
    IMAGE_DIFF = blkproc(double(ORIGINAL_IMAGE), [1 2], inline('x(1) - x(2)')); % get difference
    IMAGE_AVRG = blkproc(double(ORIGINAL_IMAGE), [1 2], inline('floor((x(1) + x(2)) / 2)')); % get average

    %% SETP 2, 3 : partitioning difference values into four sets (EZ, EN, CN, NC), creating a location map
    LOCAL_MAP_ARRAY = zeros(HEIGHT, WIDTH / 2);
    SETID = zeros(HEIGHT, WIDTH / 2); % identifies later as to which set a particulat pair belongs
    EZ_SET_Index = 0; EN1_SET_Index = 0; EN2_CN_SET_Index = 1;
    EN2_CN_SET = [];

    for i = 1 : HEIGHT
        for j = 1 : WIDTH / 2
            if (abs(2 * IMAGE_DIFF(i, j) + 0) <= min(2 * (255 - IMAGE_AVRG(i, j)), 2 * IMAGE_AVRG(i, j) + 1) ...
             || abs(2 * IMAGE_DIFF(i, j) + 1) <= min(2 * (255 - IMAGE_AVRG(i, j)), 2 * IMAGE_AVRG(i, j) + 1)) ...
              && (IMAGE_DIFF(i, j) == 0 || IMAGE_DIFF(i, j) == -1)
                % all pixel pairs that satisfy the difference value condition
                EZ_SET_Index = EZ_SET_Index + 1;
                LOCAL_MAP_ARRAY(i, j) = 1;
                SETID(i, j) = 1;
            elseif abs(2 * IMAGE_DIFF(i, j) + 0) <= min(2 * (255 - IMAGE_AVRG(i, j)), 2 * IMAGE_AVRG(i, j) + 1) ...
                || abs(2 * IMAGE_DIFF(i, j) + 1) <= min(2 * (255 - IMAGE_AVRG(i, j)), 2 * IMAGE_AVRG(i, j) + 1)
                if abs(IMAGE_DIFF(i, j)) <= THRESHOLD
                    % all pixel pairs whose difference value is less than threshold
                    EN1_SET_Index = EN1_SET_Index + 1;
                    LOCAL_MAP_ARRAY(i, j) = 1;
                    SETID(i, j) = 2;
                else
                    % set EN2_CN_SET contains all pixel pairs whose difference value is greater than threshold
                    % embedding is performed in set EN2_SET
                    EN2_CN_SET(EN2_CN_SET_Index) = IMAGE_DIFF(i, j);
                    EN2_CN_SET_Index = EN2_CN_SET_Index + 1;
                    LOCAL_MAP_ARRAY(i, j) = 0;
                    SETID(i, j) = 3;
                end
            elseif abs(2 * floor(IMAGE_DIFF(i, j) / 2) + 0) <= min(2 * (255 - IMAGE_AVRG(i, j)), 2 * IMAGE_AVRG(i, j) + 1)...
                 || abs(2 * floor(IMAGE_DIFF(i, j) / 2) + 1) <= min(2 * (255 - IMAGE_AVRG(i, j)), 2 * IMAGE_AVRG(i, j) + 1)
                % set EN2_CN_SET contains all changeable pixel pairs
                % embedding is performed in set CN_SET
                EN2_CN_SET(EN2_CN_SET_Index) = IMAGE_DIFF(i, j);
                EN2_CN_SET_Index = EN2_CN_SET_Index + 1;
                LOCAL_MAP_ARRAY(i, j) = 0;
                SETID(i, j) = 4;
            else
                % all non changable pixel pairs
                LOCAL_MAP_ARRAY(i, j) = 0;
                SETID(i, j) = 5;
            end
        end
    end
    LOCAL_MAP_VECTOR = reshape(LOCAL_MAP_ARRAY, 1, HEIGHT * WIDTH / 2);

    %% STEP 4: Collecting original LSB values
    EN2_CN_LSBs = zeros(1, length(EN2_CN_SET));
    for i = 1 : length(EN2_CN_SET)
        EN2_CN_LSBs(i) = bitget(abs(EN2_CN_SET(i)), 1);
    end

    %% STEP 5, 6 : data embedding by replacement, inverse integer transform
    % Compress the Location map using Arithmetic coding
    % find how many times 0 occurs in the LOCAL_MAP_VECTOR
    xx = find(LOCAL_MAP_VECTOR == 0);
    totalVals = HEIGHT * WIDTH / 2;
    % code the sequence using arithmetic coding
    LOCAL_MAP_VECTOR_COUNTS = [round((length(xx) / totalVals) * 100) round(((totalVals - length(xx)) / totalVals) * 100)];
    LOCAL_MAP_VECTOR = LOCAL_MAP_VECTOR + 1; % arithenco accept +ve numbers only
    LOCAL_MAP_VECTOR_ENCODED = arithenco(LOCAL_MAP_VECTOR, LOCAL_MAP_VECTOR_COUNTS);
    str = sprintf('Local Map Length = %d ------ Compressed Local Map Length = %d', HEIGHT * WIDTH / 2, length(LOCAL_MAP_VECTOR_ENCODED));
    disp(str);
    
    % STEP 5B: Compress the Original LSB's using Arithmetic coding
    % find how many times 0 occurs in the binary sequence
    xx = find(EN2_CN_LSBs == 0);
    totalVals = length(EN2_CN_LSBs);
    
    % code the sequence using arithmetic coding
    EN2_CN_LSBs_COUNTS = [round((length(xx) / totalVals) * 100) round(((totalVals - length(xx)) / totalVals) * 100)];
    EN2_CN_LSBs = EN2_CN_LSBs + 1;
    EN2_CN_LSBs_ENCODED = arithenco(EN2_CN_LSBs, EN2_CN_LSBs_COUNTS); 
    str = sprintf('Original Bits Length = %d ------ Compressed Bits Length = %d', length(EN2_CN_LSBs), length(EN2_CN_LSBs_ENCODED));
    disp(str);
    
    % Calculate Available embedding capacity
    % Calculate total Available Embedding Capacity
    totalCapacity = EZ_SET_Index + EN1_SET_Index + length(EN2_CN_SET);
    
    % Calculate payload size
    HEADERLEN = 112;
    totalPayload = length(LOCAL_MAP_VECTOR_ENCODED) + length(EN2_CN_LSBs_ENCODED);
    MAX_WATERMARK_LENGTH = totalCapacity - totalPayload - HEADERLEN;
    PAYLOAD_PADDING = [];
    if MAX_WATERMARK_LENGTH < WATERMARK_LENGTH
        WATERMARKED_IMAGE = [];
    elseif MAX_WATERMARK_LENGTH > WATERMARK_LENGTH
        PADDING_LENGTH = MAX_WATERMARK_LENGTH - WATERMARK_LENGTH;
        PAYLOAD_PADDING = zeros(1, PADDING_LENGTH);
    end
    
    str = sprintf('Total Capacity = %d ------ Watermark Length = %d', totalCapacity, WATERMARK_LENGTH);
    disp(str);
    
    % Convert header info into bit stream
    hbinSeq =                 dec2bin(LOCAL_MAP_VECTOR_COUNTS(1, 1), 8);
    hbinSeq = strcat(hbinSeq, dec2bin(LOCAL_MAP_VECTOR_COUNTS(1, 2), 8));
    hbinSeq = strcat(hbinSeq, dec2bin(EN2_CN_LSBs_COUNTS(1, 1), 8));
    hbinSeq = strcat(hbinSeq, dec2bin(EN2_CN_LSBs_COUNTS(1, 2), 8));
    hbinSeq = strcat(hbinSeq, dec2bin(length(LOCAL_MAP_VECTOR), 16));
    hbinSeq = strcat(hbinSeq, dec2bin(length(LOCAL_MAP_VECTOR_ENCODED), 16));
    hbinSeq = strcat(hbinSeq, dec2bin(length(EN2_CN_LSBs), 16));
    hbinSeq = strcat(hbinSeq, dec2bin(length(EN2_CN_LSBs_ENCODED), 16));
    hbinSeq = strcat(hbinSeq, dec2bin(WATERMARK_LENGTH, 16));
    
    HEADER = zeros(1, length(hbinSeq));
    for i = 1 : length(hbinSeq)
        HEADER(i) = str2num(hbinSeq(i));
    end

    % concatenate all bitstream to obtain the embedding stream
    B = [HEADER LOCAL_MAP_VECTOR_ENCODED EN2_CN_LSBs_ENCODED WATERMARK_PAYLOAD PAYLOAD_PADDING];
    
    % Embedd Watermark in image
    wIndex = 1;
    exitLoop = 0;
    WATERMARKED_IMAGE = zeros(HEIGHT, WIDTH);
    for i = 1 : HEIGHT
        index = 1;
        for j = 1 : WIDTH / 2
            if SETID(i, j) ~= 5 || SETID(i, j) ~= 6
                neg = 0;
                if IMAGE_DIFF(i, j) < 0
                    neg = 1;
                end
    
                if SETID(i, j) == 1 || SETID(i, j) == 2
                    % Embedd watermark by shifting
                    val = bitshift(abs(IMAGE_DIFF(i, j)), 1);                               
                elseif SETID(i, j) == 3 || SETID(i, j) == 4
                    % Embedd watermark by replacement
                    val = abs(IMAGE_DIFF(i, j));
                end
    
                binSeq = dec2bin(val, 8);
                if B(1, wIndex) == 1
                    binSeq(8) = '1';
                else
                    binSeq(8) = '0';
                end
    
                val = bin2dec(binSeq);
                
                if neg == 1
                    IMAGE_DIFF(i, j) = -val;
                else
                    IMAGE_DIFF(i, j) = val;
                end
                WATERMARKED_IMAGE(i, index) = IMAGE_AVRG(i, j) + floor((IMAGE_DIFF(i, j) + 1) / 2);
                WATERMARKED_IMAGE(i,index + 1) = IMAGE_AVRG(i, j) - floor(IMAGE_DIFF(i, j) / 2);
                index = index + 2;                
                if wIndex < totalCapacity
                    wIndex = wIndex + 1;
                else
                    exitLoop = 1;
                    break;
                end
            else
                WATERMARKED_IMAGE(i, index) = ORIGINAL_IMAGE(i, index);
                WATERMARKED_IMAGE(i, index + 1) = ORIGINAL_IMAGE(i, index + 1);
                index = index + 2;
            end
        end
        if exitLoop == 1
            break;
        end
    end
