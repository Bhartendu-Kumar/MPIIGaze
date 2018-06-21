%function tempforest(NUM_OF_GROUPS)
function tempforest


clc;

addpath /home/trakis/Downloads/MPIIGaze/Data/%@tree

NUM_OF_GROUPS = 384;%149;
HEIGHT = 15;%9;
WIDTH = 9;%15;


%%%%%%%%%% Open HDF5 training file %%%%%%%%%%



samplesInTree = zeros(1,NUM_OF_GROUPS);


for R = 5:6%11:13

for i = 1:NUM_OF_GROUPS %for each tree

	fid = H5F.open( 'myfile.h5', 'H5F_ACC_RDONLY', 'H5P_DEFAULT');	
	%%%%%%%%%% Start with the central group %%%%%%%%%%
	grpID = H5G.open(fid, strcat('/g',num2str(i)) );
	curr_samplesID 	= H5D.open(grpID, 'samples');
	curr_samples = H5D.read(curr_samplesID);
	if curr_samples == 0
		continue;
	end
	

	curr_rnearestID      = H5D.open(grpID, '20_nearestIDs');
	curr_centerID        = H5D.open(grpID, 'center');
	curr_imgsID          = H5D.open(grpID, 'data');
	curr_gazesID 	= H5D.open(grpID, 'gaze');
	curr_posesID		= H5D.open(grpID, 'headpose');

	curr_rnearest = H5D.read(curr_rnearestID);
	curr_center   = H5D.read(curr_centerID);
	curr_imgs     = H5D.read(curr_imgsID);
	curr_gazes    = H5D.read(curr_gazesID);
	curr_poses    = H5D.read(curr_posesID);


	j = 1;
	samplesInTree(i) = 0;
	MAX_CONTRIBUTION = ceil(sqrt(curr_samples));
	while j <= MAX_CONTRIBUTION
		samplesInTree(i) = samplesInTree(i) + 1;
		random = randi(curr_samples,1,1);

		treeImgs(i,:,:,samplesInTree(i) ) =  curr_imgs( :, :, 1, random);
		treeGazes(i,samplesInTree(i),: ) = curr_gazes(:,random);
		treePoses(i,samplesInTree(i),: ) = curr_poses(:,random);
		
	
		j = j + 1;
	end
	treeCenter(i,:) = curr_center;

end



for i = 1:NUM_OF_GROUPS %for each tree

	%%%%%%%% Now, continue with the R-nearest %%%%%%%%%

	for k = 1:R 
			
		localGrpID  = H5G.open(fid, strcat('/g', num2str( curr_rnearest(k))   )); 
		tempSampleID = H5D.open( localGrpID,  strcat('/g', num2str( curr_rnearest(k) ), '/samples') );
		tempSample = H5D.read( tempSampleID);
		if tempSample == 0
			H5D.close( tempSampleID);
			continue;
		end

		tempImgID  = H5D.open( localGrpID,  strcat('/g', num2str( curr_rnearest(k) ), '/data') );
		tempPoseID = H5D.open( localGrpID,  strcat('/g', num2str( curr_rnearest(k) ), '/headpose') );
		tempGazeID = H5D.open( localGrpID,  strcat('/g', num2str( curr_rnearest(k) ), '/gaze') );
		
	
		tempImgs = H5D.read( tempImgID );
		tempPoses = H5D.read( tempPoseID );
		tempGazes = H5D.read( tempGazeID );
		
		contribOfGroup = ceil( sqrt( tempSample ) );

		

		%%%%%% allagi %%%%%

		j = 1;
		while j <= contribOfGroup

		   samplesInTree(i) = samplesInTree(i) + 1;
		   random = randi(tempSample,1,1);
		   treeImgs (i, :,:,samplesInTree(i)) =  tempImgs(:,:,1,  random);
		   treeGazes(i, samplesInTree(i), :) = tempGazes(:, random);
		   treePoses(i, samplesInTree(i), :) = tempPoses( :,random);
	
	  	   j = j + 1;		
		end
		

		H5D.close( tempSampleID)
		H5D.close( tempImgID );
		H5D.close( tempPoseID);
		H5D.close( tempGazeID);

		H5G.close( localGrpID ) ;
	end
	
	
end



	%%%%%%%% Now that we created each tree's data, lets implement the algorithm %%%%%%%%%
	% - am really thankful to http://tinevez.github.io/matlab-tree/index.html
	%
	% - Each node:
	%      a) is named '(px1,px2), thres'
	%      b) has variable name: node(k)  
	%	
	% - node(k) can have:
	%      a) parent node(k/2 ) 		
	%      b) left child(2k)
	%      c) right child(2k+1)
	% - Leaves can have:
	%      d) left 2d gaze angle
	%      e) right 2d gaze angle	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	
	% xtise mono 6 gia logous oikonomias. Meta vgale tin if

	trees = buildRegressionTree( NUM_OF_GROUPS, samplesInTree, treeImgs,  treeGazes, treePoses, HEIGHT, WIDTH);


	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%% T E S T   P H A S E %%%%%%%%%%%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%%%%%%%% Open HDF5 test file %%%%%%%%%%
	fid2 = H5F.open('mytest.h5', 'H5F_ACC_RDONLY', 'H5P_DEFAULT');

	test_rnearestID      = H5D.open(fid2, '_nearestIDs');
	test_imgsID          = H5D.open(fid2, 'data');
	test_gazesID 	     = H5D.open(fid2, 'gaze');
	test_posesID	     = H5D.open(fid2, 'headpose');

	test_rnearest = H5D.read(test_rnearestID);
	test_imgs     = H5D.read(test_imgsID);
	test_gazes    = H5D.read(test_gazesID);
	test_poses    = H5D.read(test_posesID);

	ntestsamples = length( test_imgs(:,:,:,:) );
	mean_predict = zeros(1, 2*ntestsamples);
	for j = 1:3%ntestsamples

	   predict = [0 0]; 
	   for k = 1:(R+1)%each samples, run the R+1 trees

		% each tree's prediction
		predict = predict + testSampleInTree( trees(test_rnearest(k,j) ), 1, test_imgs(:,:,1,j), test_poses(:,j));
		
	   end
	   
	   %%% prediction = mean prediction of all trees %%%		 
	   predict = predict/(R+1);
	   errors(j) = norm( predict - test_gazes(:,j)',2 )%mipws einai lathos i norma?!
	 
	end
fprintf('\n\n');
	mean_error =  rad2deg( mean(  errors(1:3)) )%rad2deg( mean(  errors(1:ntestsamples)) )
	deviation  = rad2deg( std( errors(1:3)) ) %rad2deg( std( errors(1:ntestsamples)) )	

	if R == 1
	   fileID =  fopen( strcat(R,'nearest3.txt'),'w');
	elseif R == 2
	   fileID =  fopen( strcat(R,'nearest3.txt'),'w');
	elseif R == 3
	   fileID =  fopen( strcat(R,'nearest4.txt'),'w');
	elseif R == 4
	   fileID =  fopen( strcat(R,'nearest5.txt'),'w');
	elseif R == 5	
	   fileID =  fopen( strcat(R,'nearest006.txt'),'w');
	elseif R == 6
	   fileID =  fopen( strcat(R,'nearest6.txt'),'w');
	elseif R == 7
	   fileID =  fopen( strcat(R,'nearest7.txt'),'w');
	elseif R == 8
	   fileID =  fopen( strcat(R,'nearest8.txt'),'w');
	elseif R == 9
	   fileID =  fopen( strcat(R,'nearest9.txt'),'w');
	elseif R == 10
	   fileID =  fopen( strcat(R,'nearest10.txt'),'w');
	elseif R == 11
	   fileID =  fopen( strcat(R,'nearest11.txt'),'w');
	elseif R == 12
	   fileID =  fopen( strcat(R,'nearest12.txt'),'w');
	end
	fprintf(fileID,'%f\n%f', mean_error, deviation);
	fclose(fileID);
	

	H5D.close(test_rnearestID);
	H5D.close(test_imgsID);
	H5D.close(test_gazesID);
	H5D.close(test_posesID);
	 
	H5F.close(fid2);

	%%%%%%%%% Close Central Group %%%%%%%%%%%%%%%%%%
	H5D.close(curr_rnearestID);
	H5D.close(curr_centerID);
	H5D.close(curr_imgsID);
	H5D.close(curr_gazesID);
	H5D.close(curr_posesID);

	H5G.close(grpID);
	H5F.close(fid);


end

end

function val = testSampleInTree(tree, node, test_img,  test_pose )
   val = [0 0];	

   if tree.isleaf(node) 
      leafdata = tree.get(node);
      leafposes = leafdata.poses;
      leafgazes = leafdata.gazes;
      samplesInLeaf = length( leafgazes(:,1) )
      	    
      %for k = 1:samplesInLeaf
	%goodness(k) = 1/ sqrt( (leafposes(1,k,1)-test_pose(1))^2 + (leafposes(1,k,2)-test_pose(2)) ); 
    %  end	  
      
   %   for k = 1:samplesInLeaf
  %      w(k) = goodness(k)/sum(goodness(1:samplesInLeaf));
 %     end  	



      %for k = 1:samplesInLeaf
%	 val(1) = val(1) + w(k) * leafgazes(k,1);
%	 val(2) = val(2) + w(k) * leafgazes(k,2); 
%      end


      %%% not weight, but the average %%%
      val(1) = sum(leafgazes(1:samplesInLeaf, 1))/samplesInLeaf;
      val(2) = sum(leafgazes(1:samplesInLeaf, 2))/samplesInLeaf;   

      deviation = std(leafgazes(1:samplesInLeaf));
      val
      deviation
   else

      data= sscanf(tree.get(node),'Samples:%f,px1(%f,%f)-px2(%f,%f)>=%f');
      childs = tree.getchildren(node);
      if abs(test_img(data(2), data(3), 1, 1) - test_img(data(4), data(5), 1,1)) >= data(6)
         val = testSampleInTree(tree,childs(2) , test_img, test_pose );
      else
         val = testSampleInTree(tree, childs(1), test_img, test_pose );
      end
      
   end


end



function treesMy = buildRegressionTree( NUM_OF_GROUPS, fatherSizeX, treeImgsX,  treeGazesX, treePosesX, HEIGHTX, WIDTHX)
	MAX_DEPTH = 20;
	NUM_OF_WORKERS = 3;
	MAX_FATHER_SIZE = 189;%200;	
	MAX_FATHER_CHILD_DIST = 15;

	treeGazes = Composite(NUM_OF_WORKERS);
	fatherSizeTrees = Composite(NUM_OF_WORKERS);
	treeImgs = Composite(NUM_OF_WORKERS);
	treePoses = Composite(NUM_OF_WORKERS);
	HEIGHT = Composite(NUM_OF_WORKERS);
	WIDTH = Composite(NUM_OF_WORKERS);
	fatherSize = Composite(NUM_OF_WORKERS);	
	
	for w=1:NUM_OF_WORKERS
	   treeGazes{w} = treeGazesX;
	   treePoses{w} = treePosesX;
	   fatherSize{w} = fatherSizeX;
	   treeImgs{w} = treeImgsX;
	   HEIGHT{w} = HEIGHTX;
	   WIDTH{w} = WIDTHX;
	   currPtrs{w} = [1:MAX_FATHER_SIZE];
	end

	
	c = parcluster;
	c.NumWorkers = NUM_OF_WORKERS;
	saveProfile(c);

	mypool = gcp('nocreate');
	if isempty(mypool)
	   mypool =  parpool('local',3);  
	end

        spmd;


	savedNodeSize = uint16(zeros(MAX_DEPTH,2));
	currPtrs = uint16(zeros(1,MAX_FATHER_SIZE)); 

	px1_vert  = uint8(zeros(1)); 
	px1_hor = uint8(zeros(1));
	px2_vert = uint8(zeros(1));
	px2_hor = uint8(zeros(1));
	counter = uint16(zeros(1));
	

	minSquareError = zeros(1,3);
	numOfPixels = uint16(zeros(1));	
	numOfPixels = HEIGHT*WIDTH;
	bestworker = uint8(zeros(1));
	container = [];
	container.data = zeros(1,7);

	%%% allocate that memory in order to begin %%%
	%container.currPtrs = zeros(1, fatherSize(1));
	%container.savedPtrs = zeros(1, fatherSize(1));
	container.saved_curr_Ptrs = zeros(2,fatherSize(1));
	
	cache_treeImgs = uint16(zeros(fatherSize(1), 2));
        l_r_fl_fr_ptrs = uint16(zeros(4,fatherSize(1)));
        savedPtrs = uint16(zeros(MAX_DEPTH, fatherSize(1)) ); 	
	rnode_info = struct('poses', zeros(fatherSize(1),2), 'gazes', zeros(fatherSize(1),2), 'std', zeros(1,2), 'mean', zeros(1,2), 'num', zeros(1) );
	lnode_info = struct('poses', zeros(fatherSize(1),2), 'gazes', zeros(fatherSize(1),2),'std', zeros(1,2), 'mean', zeros(1,2), 'num', zeros(1) );


        bestSize = fatherSize(1);


 for i = 1:NUM_OF_GROUPS % for every tree
%   if i == 35 || i == 31 || i == 74 || i==39 ||i==26 || i ==40 || i == 27 || i == 74 || i == 10 || i == 5 || i ==6 || i==72 || i ==8 || i==10 || i==31 || i==9 || i==7 || i==6 || i==12 || i==115 || i==46 || i == 72 || i==11 || i==115 || i==47 || i==40 || i==26 || i==89 || i == 72 || i == 39 || i ==5 || i == 51 || i == 46 || i == 9 || i == 74 || i == 21 || i == 114 || i == 47 || i == 115 || i == 106 || i == 20 || i == 33 || i == 68 || i == 33 || i == 13 || i == 62 %006

%if i==302.0 || i== 40.0	 || i== 54.0 || i==	5.0	|| i==89.0	|| i==49.0 || i==	71.0 || i==	83.0 || i==	127.0	|| i==9.0	|| i==88.0 || i==33.0 || i==	204.0 || i==	28.0 || i==	118.0 || i ==	10.0 || i==	41.0 || i==	65.0 || i==	87.0 || 	i==36.0	|| i==161.0 || i==	117.0 || i==118.0 || i==	204.0 || i==	161.0 || i== 	33.0||	i==44.0	|| i==117.0  || i==265.0  || i==144.0 || i==	167.0 || i==108.0 || i==9.0 || i==189.0 || i==	150.0 || i==29.0 || i==	13.0 || i ==117.0  || i==89.0 || i==124.0 || i==	246.0 || i==1.0 || i==274.0 || i==328.0 || i==	35.0 || i==36.0 || i==	137.0 || i==22.0 || i==	290.0 || i==7.0  || i==165.0 || i==86.0 || i==8.0 || i==73.0 || i==145.0 || i==105.0 || i==47.0 || i==300.0


if i==302.0 || i== 40.0	 || i== 54.0 || i==	5.0	|| i==89.0	|| i==49.0 || i==	71.0 || i==	83.0 || i==	127.0	|| i==9.0	|| i==88.0 || i==33.0 || i==	204.0 || i==	28.0 || i==	118.0 || i ==	10.0 || i==	41.0 || i==	65.0 || i==	87.0 || 	i==36.0	|| i==161.0 || i==	117.0 || i==118.0 || i==	204.0 || i==	161.0 || i== 	33.0||	i==44.0	|| i==117.0  || i==265.0  || i==144.0 || i==	167.0 || i==108.0 || i==9.0 || i==189.0 || i==	150.0 || i==29.0 || i==	13.0 || i ==117.0  || i==89.0 || i==124.0 || i==	246.0 || i==1.0 || i==274.0 || i==328.0 || i==	35.0 || i==36.0 || i==	137.0 || i==22.0 || i==	290.0 || i==7.0  || i==165.0 || i==86.0 || i==8.0 || i==73.0 || i==145.0 || i==105.0 || i==47.0 || i==300.0


        if  (fatherSize(i) > bestSize) || (bestSize - fatherSize(i) > MAX_FATHER_CHILD_DIST ) 
	  %%% reallocate memory when the condition is true %%%    
	   bestSize = fatherSize(i);
	    
	   cache_treeImgs = [];
	   l_r_fl_fr_ptrs = [];
	   savedPtrs = [];
	   container.saved_curr_Ptrs = [];

	   savedPtrs = uint16(zeros(MAX_DEPTH, fatherSize(i)) );
           cache_treeImgs = uint16( zeros(fatherSize(i), 2));
           l_r_fl_fr_ptrs = uint16(zeros(4,fatherSize(i))); 
  	   container.saved_curr_Ptrs = uint16(zeros(2,fatherSize(i)) );
	   rnode_info = struct('poses', zeros(fatherSize(1),2), 'gazes', zeros(fatherSize(1),2),'std', zeros(1,2), 'mean', zeros(1,2) ,'num', zeros(1));
	   lnode_info = struct('poses', zeros(fatherSize(1),2), 'gazes', zeros(fatherSize(1),2),'std', zeros(1,2), 'mean', zeros(1,2), 'num', zeros(1) );

	   
	end

       stackindex = 0;
       state = 1;	
       trees(i) = tree(strcat('RegressionTree_', num2str(i) ));
       node_i = 1;
       currPtrs = [1:fatherSize(i)];
       while state ~= 2 
	
	   %for each node
	   minSquareError = [10000 10000 10000];
	   minPx1_vert =    10000; % something random here
	   minPx1_hor =     10000; % also here
	   minPx2_vert=     10000; % and here..
	   minPx2_hor =     10000; % and here 
	   bestThres  =     10000; % ah, and here
	 
          
	   counter = labindex;
	   while counter <= numOfPixels-1
		
	
	        px1_vert = ceil( (counter/WIDTH));
	        px1_hor =  1 +  mod(counter-1, (WIDTH) );

      	       % sorry for the huge equations below
	       % these equations are made in order to prevent 2 pixels
	       % to be examined twice

	       for px2_vert = ( px1_vert + floor(px1_hor/WIDTH)  ):HEIGHT
	          for px2_hor = (1 + mod( px1_hor, WIDTH )):WIDTH

		     %%% create a cache array (px1_vert_px1_hor, curr %%%
	             for j = 1:fatherSize(i)
		        cache_treeImgs(j,1) = treeImgs(i, px1_vert,px1_hor, currPtrs( j)  );
		        cache_treeImgs(j,2) = treeImgs(i, px2_vert,px2_hor, currPtrs( j)  );
		     end
		
                     if  sqrt( (px1_vert -px2_vert)^2+(px1_hor-px2_hor)^2 ) < 6.5             
		        for thres = 25:30%1:50
			   l = 0;
			   r = 0;			
			   meanLeftGaze = [0 0];
			   meanRightGaze = [0 0];
			   for j = 1:fatherSize(i)
 
			      if abs(  cache_treeImgs(j,1) - cache_treeImgs(j,2) ) < thres			    

			          %left child
			         l = l + 1;
				 l_r_fl_fr_ptrs(1,l) = currPtrs(j);			
				 
			
			
				 meanLeftGaze(1) = meanLeftGaze(1) + treeGazes(i,currPtrs(j),1);			       
				 meanLeftGaze(2) = meanLeftGaze(2) + treeGazes(i,currPtrs(j),2);	
			      else
			            %right child
			            r = r + 1;
				    l_r_fl_fr_ptrs(2,r) = currPtrs(j);
  				      
				    meanRightGaze(1) = meanRightGaze(1) + treeGazes(i,currPtrs(j),1);
				    meanRightGaze(2) = meanRightGaze(2) + treeGazes(i,currPtrs(j),2);
			       end
			    end
	
			       meanLeftGaze = meanLeftGaze  / l;
			       meanRightGaze = meanRightGaze/ r;

			       squareError = 0;
				for j = 1:l	
				   squareError=squareError + (meanLeftGaze(1)-treeGazes(i, l_r_fl_fr_ptrs(1,l),1))^2 + (meanLeftGaze(2)-treeGazes(i,l_r_fl_fr_ptrs(1,l),2))^2;	
			       end
			       for j = 1:r
				   squareError=squareError + (meanRightGaze(1)-treeGazes(i,l_r_fl_fr_ptrs(2,r),1))^2 + (meanRightGaze(2)-treeGazes(i, l_r_fl_fr_ptrs(2,r), 2))^2;	
		               end
			       
		
			       if squareError < minSquareError(labindex)
			           minSquareError(labindex) = squareError;
			           minPx1_vert =    px1_vert; % something random here
			           minPx1_hor =     px1_hor; % also here
			   	   minPx2_vert=     px2_vert; % and here..
			   	   minPx2_hor =     px2_hor; % and here
			   	   bestThres  =     thres;

				   ltreeSize = l;
			   	   rtreeSize = r;

				   l_r_fl_fr_ptrs(3,1:l) = l_r_fl_fr_ptrs(1,1:l);
				   l_r_fl_fr_ptrs(4,1:r) = l_r_fl_fr_ptrs(2,1:r);
		
                           	   rtree_meanGaze = meanRightGaze;
			   	   ltree_meanGaze = meanLeftGaze;
				   stdLeftGaze(1) =  std(  treeGazes(i, l_r_fl_fr_ptrs(1,1:l), 1)   );
				   stdLeftGaze(2) =  std(  treeGazes(i, l_r_fl_fr_ptrs(1,1:l), 2)   );

				   stdRightGaze(1) = std(  treeGazes(i, l_r_fl_fr_ptrs(2,1:r), 1)   );
				   stdRightGaze(2) = std(  treeGazes(i, l_r_fl_fr_ptrs(2,1:r), 2)   );
				 
				end	 	
		             end%thres
		          end%end if < 6.5	
		       end%px2_hor
		    end%px2_vers 	
	         %end %px1_hor
		 counter = counter + numlabs;
           end %endof px1_vert

	 
             rcvWkrIdx = mod(labindex, numlabs) + 1; % one worker to the right
	     srcWkrIdx = mod(labindex - 2, numlabs) + 1; % one worker to the left

	     labBarrier;	 
	     %%% take data from the left and give to the right %%%
	     minSquareError( srcWkrIdx ) = labSendReceive(rcvWkrIdx,srcWkrIdx, minSquareError(labindex) );


	     labBarrier;
	     %%% take data from the right %%%
	     minSquareError(rcvWkrIdx) = labSendReceive(srcWkrIdx,rcvWkrIdx,minSquareError(labindex));

	    labBarrier;

	 %%% sychronize before finding the best worker %%%
	 bestworker = 1;
	 minError = minSquareError(1);	
	 for k = 2:numlabs
	    if minSquareError(k) < minError
	       minError = minSquareError(k);
 	       bestworker = k;
	    end
	 end
	

         if bestworker == labindex

	   %%%%%% Recursion starts here %%%%%	
	   if (ltreeSize > 0 && rtreeSize > 0)
	      state = 1;

              trees(i)=trees(i).set(node_i,strcat('Samples:',num2str(fatherSize(i)),',px1(', num2str(minPx1_vert),',',num2str(minPx1_hor),')-','px2(',num2str(minPx2_vert),',',num2str(minPx2_hor),')>=', num2str(bestThres) ));  


	   
	      rnode_info.poses = treePoses(i, l_r_fl_fr_ptrs(4,1:rtreeSize), :);
	      rnode_info.gazes = treeGazes(i, l_r_fl_fr_ptrs(4,1:rtreeSize), :);
	      rnode_info.num = rtreeSize;
	      rnode_info.mean = meanRightGaze;
	      rnode_info.std = stdRightGaze;
	     
	      lnode_info.poses = treePoses(i, l_r_fl_fr_ptrs(3,1:ltreeSize), :);
	      lnode_info.gazes = treeGazes(i, l_r_fl_fr_ptrs(3,1:ltreeSize), :);
	      rlnode_info.num = ltreeSize;
	      lnode_info.mean = meanLeftGaze;
	      lnode_info.std = stdLeftGaze;

	      [trees(i) lnode] = trees(i).addnode(node_i, lnode_info);
	      [trees(i) rnode] = trees(i).addnode(node_i, rnode_info);
	      
	      
	 
	      % start saving the left brother     
	      stackindex = stackindex + 1;
	      savedNodeSize(stackindex,1) = lnode;
	      savedNodeSize(stackindex,2) = ltreeSize;
	      savedPtrs(stackindex, 1:ltreeSize) = l_r_fl_fr_ptrs(3,1:ltreeSize);
	 

	      %%%   prepare data for right son %%%
	      node_i = rnode;
	      fatherSize(i) = rtreeSize;
	      currPtrs(1:rtreeSize) =  l_r_fl_fr_ptrs(4,1:rtreeSize); 	      
	      container.data = [state numOfPixels  stackindex  fatherSize(i)  node_i  savedNodeSize(stackindex,1)  savedNodeSize(stackindex,2) ];
	      container.trees = trees(i);
	      container.saved_curr_Ptrs(1, 1:ltreeSize) =  l_r_fl_fr_ptrs(3,1:ltreeSize);
	      container.saved_curr_Ptrs(2, 1:fatherSize(i) ) = currPtrs(1:fatherSize(i) );

           else  %2
	      if stackindex == 0
		 state = 2;
		 container.data(1) = 2;
	      else 
		 

		 state = 3;        
	     	 node_i = savedNodeSize(stackindex,1);
	         fatherSize(i) = savedNodeSize(stackindex,2);
	         currPtrs(1:fatherSize(i)) = savedPtrs(stackindex,1:fatherSize(i));
	         stackindex = stackindex - 1;

		 container.data = [state numOfPixels stackindex fatherSize(i) node_i ];
	         container.saved_curr_Ptrs(2,1:fatherSize(i)) = currPtrs(1:fatherSize(i));	
	      end
	    
	   end %2	
        end 
	  



	labBarrier;
	if labindex ~= bestworker

	    container = labBroadcast(bestworker);
	    if container.data(1) == 1 %state = 1

	       stackindex = container.data(3);
	       fatherSize(i) = container.data(4);
	       node_i = container.data(5);
	       savedNodeSize(stackindex,1) = container.data(6);
	       savedNodeSize(stackindex,2) = container.data(7);%ltreeSize
	       trees(i) = container.trees;	          	      

	       savedPtrs(stackindex,1:savedNodeSize(stackindex,2)) = container.saved_curr_Ptrs(1,1:savedNodeSize(stackindex,2));	       
	       currPtrs(1:fatherSize(i)) = container.saved_curr_Ptrs(2,1:fatherSize(i));
	      
	    elseif container.data(1) == 2
	       state = 2;   


	    else  %container.data(1) == 3 %[state poulo stackindex fatherSize node_i ];
		state = 3;

	        %%% o stackindex erxetai meiwmenos kata 1 %%%
	       stackindex = container.data(3);
	       fatherSize(i) = container.data(4);
	       node_i = container.data(5);
	       currPtrs(1:fatherSize(i)) = container.saved_curr_Ptrs(2,1:fatherSize(i));
	       
	    end
	else
	   labBroadcast(bestworker, container); 
	end


	%isws
	labBarrier;
       
   end %while loop


    if labindex == 1
	i
        disp(trees(i).tostring);
    end 

  end %if tree  
 
 end %treeCompleted

 
  
   end%end of spmd

   treesMy = trees{1};



end %end of program

