clear all;
close all;

ORIGINAL_IMAGE = imread('boat_256x256.tif');
PAYLOAD = [1 0 1 0 0 1 1 0 1 1];
[WATERMARKED_IMAGE] = DE_Encode(ORIGINAL_IMAGE, PAYLOAD);

str = sprintf('Payload(bpp) = %f ----- Total bits = %d', length(PAYLOAD) / (size(ORIGINAL_IMAGE, 1) * size(ORIGINAL_IMAGE, 2)), length(PAYLOAD));
disp(str);

[PSNR_OUT, Z] = psnr(ORIGINAL_IMAGE, WATERMARKED_IMAGE);
str = sprintf('PSNR = %f', PSNR_OUT);
disp(str);

imwrite(uint8(WATERMARKED_IMAGE), 'WatermarkedImage.tif', 'tif');

figure,imshow(ORIGINAL_IMAGE, []), title('Original Image')
figure,imshow(WATERMARKED_IMAGE, []), title('Watermarked Image')
[WATERMARK_PAYLOAD ORG_IMAGE] = DE_Decode(WATERMARKED_IMAGE);

