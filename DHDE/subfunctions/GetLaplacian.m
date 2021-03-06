%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A Unified Approach of Multi-scale Deep and Hand-crafted Features
% for Defocus Estimation
%
% Jinsun Park, Yu-Wing Tai, Donghyeon Cho and In So Kweon
%
% CVPR 2017
%
% Please feel free to contact if you have any problems.
% 
% E-mail : Jinsun Park (zzangjinsun@gmail.com)
% Project Page : https://github.com/zzangjinsun/DHDE_CVPR17/
%
%
%
% Name   : MattingLaplacian
% Input  : rgbImg - input guide image
%          params - parameters
% Output : L      - matting laplacian matrix
%
% This function is a modified version of the source codes from
% the following papers:
%
% Levin, Anat, Dani Lischinski, and Yair Weiss.
% "A closed-form solution to natural image matting."
% Pattern Analysis and Machine Intelligence,
% IEEE Transactions on 30.2 (2008): 228-242.
%
% Zhuo, Shaojie, and Terence Sim.
% "Defocus map estimation from a single image."
% Pattern Recognition 44.9 (2011): 1852-1858.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function L = GetLaplacian(rgbImg, params)
    % Parsing Parameters
    propEps = params.propEps;
    rNeighbor = params.propRadius;
    wNeighbor = 2*rNeighbor+1;

    [R, C, CH] = size(rgbImg);
    denom = boxfilter(ones(R, C), rNeighbor);

    % Calculate mean and variance
    mR = boxfilter(rgbImg(:, :, 1), rNeighbor)./denom;
    mG = boxfilter(rgbImg(:, :, 2), rNeighbor)./denom;
    mB = boxfilter(rgbImg(:, :, 3), rNeighbor)./denom;

    vRR = boxfilter(rgbImg(:, :, 1).*rgbImg(:, :, 1), rNeighbor)./denom - mR.*mR;
    vRG = boxfilter(rgbImg(:, :, 1).*rgbImg(:, :, 2), rNeighbor)./denom - mR.*mG;
    vRB = boxfilter(rgbImg(:, :, 1).*rgbImg(:, :, 3), rNeighbor)./denom - mR.*mB;
    vGG = boxfilter(rgbImg(:, :, 2).*rgbImg(:, :, 2), rNeighbor)./denom - mG.*mG;
    vGB = boxfilter(rgbImg(:, :, 2).*rgbImg(:, :, 3), rNeighbor)./denom - mG.*mB;
    vBB = boxfilter(rgbImg(:, :, 3).*rgbImg(:, :, 3), rNeighbor)./denom - mB.*mB;

    nRoi = wNeighbor^2;
    nVals = (nRoi^2)*(R-2*rNeighbor)*(C-2*rNeighbor);
    
    mIdx = reshape(1:R*C, R, C);
    mEye = propEps*eye(CH, CH);
    
    Vals = zeros(nVals, 1);
    Rows = zeros(nVals, 1);
    Cols = zeros(nVals, 1);
    
    cnt = 0;
    
    for r=1+rNeighbor:R-rNeighbor
        for c=1+rNeighbor:C-rNeighbor
            
            s = [vRR(r, c), vRG(r, c), vRB(r, c);
                 vRG(r, c), vGG(r, c), vGB(r, c);
                 vRB(r, c), vGB(r, c), vBB(r, c)] + mEye;
                 
            avg = [mR(r,c), mG(r,c), mB(r,c)];

            wIdx = mIdx(r-rNeighbor:r+rNeighbor,c-rNeighbor:c+rNeighbor);
            wIdx = wIdx(:);

            roi = rgbImg(r-rNeighbor:r+rNeighbor,c-rNeighbor:c+rNeighbor,:);

            roi = reshape(roi, nRoi, CH);
            
            roi = roi - avg(ones(nRoi, 1), :);
            
            % Direct Calculation is faster (for r = 1 only)
            sInv = [s(2,2)*s(3,3) - s(2,3)*s(3,2), s(1,3)*s(3,2) - s(1,2)*s(3,3), s(1,2)*s(2,3) - s(1,3)*s(2,2);
                    s(2,3)*s(3,1) - s(2,1)*s(3,3), s(1,1)*s(3,3) - s(1,3)*s(3,1), s(1,3)*s(2,1) - s(1,1)*s(2,3);
                    s(2,1)*s(3,2) - s(2,2)*s(3,1), s(1,2)*s(3,1) - s(1,1)*s(3,2), s(1,1)*s(2,2) - s(1,2)*s(2,1)]/ ...
                    (s(1,1)*s(2,2)*s(3,3) + s(2,1)*s(3,2)*s(1,3) + s(3,1)*s(1,2)*s(2,3) ...
                    - s(1,1)*s(3,2)*s(2,3) - s(3,1)*s(2,2)*s(1,3) - s(2,1)*s(1,2)*s(3,3));
            
            vals = (1 + roi*sInv*roi')/nRoi;
            
%             vals = (1 + roi*inv(s)*roi')/nRoi;
            
            Rows(cnt+1:cnt+nRoi^2) = reshape(wIdx(:, ones(nRoi, 1)), nRoi^2, 1);
            wIdx = wIdx';
            Cols(cnt+1:cnt+nRoi^2) = reshape(wIdx(ones(nRoi, 1), :), nRoi^2, 1);

            Vals(cnt+1:cnt+nRoi^2) = vals(:);
            
            cnt = cnt+nRoi^2;
        end
    end
    
    L = sparse(Rows, Cols, Vals, R*C, R*C);
    
    sumL = sum(L, 2);
    
    L = spdiags(sumL(:), 0, R*C, R*C) - L;

end

function imDst = boxfilter(imSrc, r)

    %   BOXFILTER   O(1) time box filtering using cumulative sum
    %
    %   - Definition imDst(x, y)=sum(sum(imSrc(x-r:x+r,y-r:y+r)));
    %   - Running time independent of r; 
    %   - Equivalent to the function: colfilt(imSrc, [2*r+1, 2*r+1], 'sliding', @sum);
    %   - But much faster.

    [hei, wid] = size(imSrc);
    imDst = zeros(size(imSrc));

    %cumulative sum over Y axis
    imCum = cumsum(imSrc, 1);
    %difference over Y axis
    imDst(1:r+1, :) = imCum(1+r:2*r+1, :);
    imDst(r+2:hei-r, :) = imCum(2*r+2:hei, :) - imCum(1:hei-2*r-1, :);
    imDst(hei-r+1:hei, :) = repmat(imCum(hei, :), [r, 1]) - imCum(hei-2*r:hei-r-1, :);

    %cumulative sum over X axis
    imCum = cumsum(imDst, 2);
    %difference over Y axis
    imDst(:, 1:r+1) = imCum(:, 1+r:2*r+1);
    imDst(:, r+2:wid-r) = imCum(:, 2*r+2:wid) - imCum(:, 1:wid-2*r-1);
    imDst(:, wid-r+1:wid) = repmat(imCum(:, wid), [1, r]) - imCum(:, wid-2*r:wid-r-1);
end


