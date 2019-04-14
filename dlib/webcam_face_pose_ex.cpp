// The contents of this file are in the public domain. See LICENSE_FOR_EXAMPLE_PROGRAMS.txt
/*

    This example program shows how to find frontal human faces in an image and
    estimate their pose.  The pose takes the form of 68 landmarks.  These are
    points on the face such as the corners of the mouth, along the eyebrows, on
    the eyes, and so forth.  
    

    This example is essentially just a version of the face_landmark_detection_ex.cpp
    example modified to use OpenCV's VideoCapture object to read from a camera instead 
    of files.


    Finally, note that the face detector is fastest when compiled with at least
    SSE2 instructions enabled.  So if you are using a PC with an Intel or AMD
    chip then you should enable at least SSE2 instructions.  If you are using
    cmake to compile this program you can enable them by using one of the
    following commands when you create the build project:
        cmake path_to_dlib_root/examples -DUSE_SSE2_INSTRUCTIONS=ON
        cmake path_to_dlib_root/examples -DUSE_SSE4_INSTRUCTIONS=ON
        cmake path_to_dlib_root/examples -DUSE_AVX_INSTRUCTIONS=ON
    This will set the appropriate compiler options for GCC, clang, Visual
    Studio, or the Intel compiler.  If you are using another compiler then you
    need to consult your compiler's manual to determine how to enable these
    instructions.  Note that AVX is the fastest but requires a CPU from at least
    2011.  SSE4 is the next fastest and is supported by most current machines.  
*/


#include <dlib/opencv.h>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/image_processing/render_face_detections.h>
#include <dlib/image_processing.h>
#include <dlib/gui_widgets.h>
#include <opencv2/opencv.hpp>
#include <thread>
#include "Regressor.h"
#include "Graphics.h"
using namespace dlib;
using namespace std;


volatile int pixW = 200, pixH=200;
void GraphicsTread() { 
	
	bool quit = false;
    SDL_Event event;
    Graphics graphics;
    
    graphics.init();
    graphics.setPos(pixW,pixH,false);//graphics.setPos(400,400,false);
    //SDL_Delay(3000);
    //graphics.setPos(700,700,false);
    //SDL_Delay(3000);
   // graphics.setPos(400,400,false);
    while (!quit) {
        SDL_WaitEvent(&event);
        switch (event.type) {
            case SDL_QUIT:
                quit = true;
                break;
        }
        graphics.setPos(pixW,pixH,false);
    }
    graphics.close(); 
}

// Checks if a matrix is a valid rotation matrix.
bool isRotationMatrix(cv::Mat &R)
{
    cv::Mat Rt;
    transpose(R, Rt);
    cv::Mat shouldBeIdentity = Rt * R;
    cv::Mat I = cv::Mat::eye(3,3, shouldBeIdentity.type());
     
    return  norm(I, shouldBeIdentity) < 1e-6;
     
}
 
// Calculates rotation matrix to euler angles
// The result is the same as MATLAB except the order
// of the euler angles ( x and z are swapped ).
//cv::Vec3f rotationMatrixToEulerAngles(cv::Mat &R)
void rotationMatrixToEulerAngles(cv::Mat &R, float *headpose)
{
    headpose[0] = -atan2(R.at<double>(0,2),R.at<double>(2,2));
    headpose[1] =-asin(R.at<double>(1,2));
	//return cv::Vec3f(-asin(R.at<double>(1,2)),-atan2(R.at<double>(0,2),R.at<double>(2,2)),1.0);

/*
    assert(isRotationMatrix(R));
     
    float sy = sqrt(R.at<double>(0,0) * R.at<double>(0,0) +  R.at<double>(1,0) * R.at<double>(1,0) );
 
    bool singular = sy < 1e-6; // If
 
    float x, y, z;
    if (!singular)
    {
        x = atan2(R.at<double>(2,1) , R.at<double>(2,2));
        y = atan2(-R.at<double>(2,0), sy);
        z = atan2(R.at<double>(1,0), R.at<double>(0,0));
    }
    else
    {
        x = atan2(-R.at<double>(1,2), R.at<double>(1,1));
        y = atan2(-R.at<double>(2,0), sy);
        z = 0;
    }
    return cv::Vec3f(x, y, z);   
*/
}
int main()
{
    try
    {
        cv::VideoCapture cap(0);
        if (!cap.isOpened())
        {
            cerr << "Unable to connect to camera" << endl;
            return 1;
        }

        image_window win;

        // Load face detection and pose estimation models.
        frontal_face_detector detector = get_frontal_face_detector();
        shape_predictor pose_model;
        deserialize("../../Downloads/shape_predictor_68_face_landmarks.dat") >> pose_model;
	
		//define our 3D face model:
		std::vector<cv::Point3d> model3Dpoints;
    	model3Dpoints.push_back(cv::Point3d(-45.097f, -0.48377f, 2.397f));// Right eye: Right Corner
   		model3Dpoints.push_back(cv::Point3d(-21.313f, 0.48377f, -2.397f));// Right eye: Left Corner
    	model3Dpoints.push_back(cv::Point3d(21.313f, 0.48377f, -2.397f));// Left eye: Right Corner
    	model3Dpoints.push_back(cv::Point3d(45.097f, -0.48377f, 2.397f));// Left eye: Left Corner
    	model3Dpoints.push_back(cv::Point3d(-26.3f, 68.595f, -9.8608e-32f));// Mouth: Right Corner
    	model3Dpoints.push_back(cv::Point3d(26.3f, 68.595f, -9.8608e-32f));//Mouth: Left Corner	 

    	// 1a.Calculate the midpoint for right eye e_h in HEAD COORDS(Face Model)
        //cv::Mat rightmidpoints(cv::Point3d((-45.097f-21.313f)/2,(-0.48377f+0.48377f)/2, (2.397f-2.397f)/2));
		cv::Point3d rightmidpoints(cv::Point3d((-45.097f-21.313f)/2,(-0.48377f+0.48377f)/2, (2.397f-2.397f)/2));


        cout << "midpoits are" << rightmidpoints << endl;

        // 1b.Calculate the midpoint for left eye e_h in HEAD COORDS(Face Model)
        cv::Point3d leftmidpoints(cv::Point3d((21.313f +45.097f)/2,(0.48377f-0.48377f)/2, (-2.397f+2.397f)/2));
        //cv::Point3d leftmidpoints(cv::Point3d((21.313f +45.097f)/2,(0.48377f+-0.48377f)/2, (-2.397f+2.397f)/2));


        // 1c.Calculate xr(x axis) of the head coordinate system
        //cv::Mat xr =(leftmidpoints-rightmidpoints);///cv::norm(leftmidpoints-rightmidpoints);
        cv::Point3d xr =(leftmidpoints-rightmidpoints)/cv::norm(leftmidpoints-rightmidpoints);

        Regressor regressor;
        regressor.load_model();
     
        //Create thread for graphics
        std::thread t1(GraphicsTread);


        // Grab and process frames until the main window is closed by the user.
        while(!win.is_closed())
        {
		
            // Grab a frame
            cv::Mat temp;
            //cv::flip(temp, temp, 1);
            if (!cap.read(temp))
            {
                break;
            }
            //printf("rows are %d\n", temp.rows);//cols=640,rows=460
            // Turn OpenCV's Mat into something dlib can deal with.  Note that this just
            // wraps the Mat object, it doesn't copy anything.  So cimg is only valid as
            // long as temp is valid.  Also don't do anything to temp that would cause it
            // to reallocate the memory which stores the image as that will make cimg
            // contain dangling pointers.  This basically means you shouldn't modify temp
            // while using cimg.
            cv_image<bgr_pixel> cimg(temp);
        

            // Detect faces 
            std::vector<rectangle> faces = detector(cimg);
            // Find the pose of each face.
            std::vector<full_object_detection> shapes2d;

            //to for-loop afto ekteleitai mono an uparxoun faces stin eikona
            for (unsigned long i = 0; i < faces.size(); ++i) {
                full_object_detection shape = pose_model(cimg,faces[i]);//to pose model den einai function!
                std::vector<cv::Point2d> image_points;


                //we know the (x,y) image landmark positions
                image_points.push_back(cv::Point2d(shape.part(36).x(),shape.part(36).y()));    // Nose tip
                image_points.push_back(cv::Point2d(shape.part(39).x(),shape.part(39).y()));    // Chin
                image_points.push_back(cv::Point2d(shape.part(42).x(),shape.part(42).y()));    // Left eye left corner
                image_points.push_back(cv::Point2d(shape.part(45).x(),shape.part(45).y()));    // Right eye right corner
                image_points.push_back(cv::Point2d(shape.part(48).x(),shape.part(48).y()));    // Left Mouth corner
                image_points.push_back(cv::Point2d(shape.part(54).x(),shape.part(54).y()));    // Right mouth corner
                //tha xreiastoume ta 6 parakatw 2d landmarks(se pixels):
                //n.36: deksia akri deksiou matiou
                //n.39: aristeri akri deksiou matiou
                //n.42: deksia akri aristerou matiou
                //n.45: aristeri akri aristerou matiou
                //n.48: deksia akri stoma
                //n.54: aristeri akri stoma                                



                //h metavlith "shapes2d" einai gia to windowDraw() katw katw
                //cout << "pixel position of 1st part: " << shape.part(0) << endl;
                shapes2d.push_back(pose_model(cimg, faces[i]));//size=68, shape.part(0)         


				//Estimation of intristic characteristics(We can also use calibrateCamera() from opencv) 
    			double focal_length = temp.cols;// Approximate focal length.
   				cv::Point2d center = cv::Point2d(temp.cols/2,temp.rows/2);//rows=460, cols=640
    			cv::Mat Cr = (cv::Mat_<double>(3,3) << focal_length, 0, center.x, 0 , focal_length, center.y, 0, 0, 1);
    			cv::Mat dist_coeffs = cv::Mat::zeros(4,1,cv::DataType<double>::type);// Assuming no lens distortion
				//cout << "Camera Matrix " << endl << camera_matrix << endl ;
    	
    			// Output rotation and translation
    			cv::Mat rotation_vector; // Rotation in axis-angle form
    			cv::Mat translation_vector;	
				//cv::Point3d translation_vector;

				//Calculate from "solvePnP" the rvec and tvec(extrinsics params). These values are in the Camera-Coordinate System
    			cv::solvePnP(model3Dpoints, image_points,Cr, dist_coeffs, rotation_vector, translation_vector);
    			//cout << "Rotation_vector " << endl << rotation_vector << endl;
    		    //cout << "translation_vector(matrix) "  << translation_vector << endl;		 
                //cout << "1)translation_vector(Point3d) in mm: "  << (cv::Point3d)translation_vector << endl;        


    			//Calculate Rotation_matrix from rotation_vector using Rodriguez(), find 3d points from 2d
    			cv::Mat Rr;
    			cv::Rodrigues(rotation_vector, Rr);
    			//cout << "Rr" << Rr << endl;


    			//obtain yaw, pitch and roll(x,y,z) from Rotation Matrix.Rotation is calculated as: R=Rx*Ry*Rz,where Rx,Ry,Rz are the rotation matrices around the axes
    			//cv::Vec3f eulerAngles;
    			float eulerAngles[2];
                //eulerAngles = rotationMatrixToEulerAngles(Rr);
                rotationMatrixToEulerAngles(Rr,eulerAngles);

    			//cout << "eulerAngles:("<<eulerAngles[0]* 180.0/M_PI<<","<<eulerAngles[1]* 180.0/M_PI<<")"<<endl;
                //cout << "eulerAngles:" << eulerAngles << endl;    
                cv::Mat zc_mat=Rr* (cv::Mat)leftmidpoints+translation_vector;
                cv::Point3d zc = (cv::Point3d)zc_mat;
            
    			// 2b.Calculate rotated y-axis: yc = zc x xr
    			cv::Point3d yc = zc.cross(xr);//xr.cross((cv::Point3d)translation_vector);
    		
    			// 2c.Calculate x-axis of the rotated camera
    			cv::Point3d xc = yc.cross(zc);//(cv::Point3d)translation_vector);//yc.cross(cameramidpoints);   			
              
                // 3.Calculate the conversion matrix: M = S * R, where
                //   S = diag(1,1,dn/||e_r||) and R = (RotationMatrix)^-1
                // dn is the distance between e_r and the (0,0,0) of the scaled CAMERA COORDS and is 600mm
        	    // M matrix describes the conversion from non-normalised to normalised CAMERA COORDS
				//cv::Mat S = cv::Mat::Mat(Size size, int type, void* data, size_t step=AUTO_STEP);                
    			// Take also into account that the inverse and transpose of rotation matrices are the same!
                cv::Mat xc_norm = (cv::Mat)xc/cv::norm((cv::Mat)xc, cv::NORM_L2, cv::noArray());
                cv::Mat yc_norm = (cv::Mat)yc/cv::norm((cv::Mat)yc, cv::NORM_L2, cv::noArray());
    			cv::Mat zc_norm = (cv::Mat)zc/cv::norm((cv::Mat)zc, cv::NORM_L2, cv::noArray());


                cv::Mat R = (cv::Mat_<float>(3,3) << xc_norm.at<double>(0),yc_norm.at<double>(0),zc_norm.at<double>(0),xc_norm.at<double>(1),yc_norm.at<double>(1),zc_norm.at<double>(1),xc_norm.at<double>(2),yc_norm.at<double>(2),zc_norm.at<double>(2));
                R = R.t();

                cv::Mat S = (cv::Mat_<float>(3, 3) << 1,0,0,0,1,0,0,0, 600/cv::norm((cv::Mat)translation_vector, cv::NORM_L2, cv::noArray() ));//cv::magnitude(cameramidpoints));
				S.convertTo(S, CV_32FC1);
				Rr.convertTo(Rr, CV_32FC1);
                cv::Mat M = S * R;// rotation_matrix.inv();//.t();
               

                // 4.Calculate the normalised projection matrix C_n=[f_x,0,c_x; 0,f_y,c_y; 0,0,1]
                int fx = 960;//in milimeters
                int fy = 960;
                int cx = 30;//pixels
                int cy = 18;
                int NWIDTH = 60;
                int NHEIGHT = 36;
                cv::Mat Cn = (cv::Mat_<float>(3, 3) << fx,0,cx,0,fy,cy,0,0,1);
                //cout << "Cn matrix is:" << Cn << endl;

                // 5.Calculate the warp perspective image transformation matrix
                Cr.convertTo(Cr, CV_32FC1);
                cv::Mat W = Cn * M * Cr.inv();
                //cout << "W matrix is:" << W << endl;

                //normalized image has size:60x36
                cv::Mat output = cv::Mat::zeros(cv::Size(NWIDTH, NHEIGHT), CV_32FC1); 
                cv::warpPerspective(temp,output, W, output.size());

                // 6.Calculate new Rotation matrix: R_n = R * R_r 
                cv::Mat Rn = R*Rr;
                //cout << "Rn is " << Rn << endl;
                cv::Vec3f eulerAngles_norm =  rotationMatrixToEulerAngles(Rn);
                eulerAngles_norm = eulerAngles_norm * 180.0/M_PI;
                cout << "eulerAngles_norm are:(" << eulerAngles_norm[2]<<","<< eulerAngles_norm[1]<<","<<eulerAngles_norm[0]<<")" << endl;
                


                // 9.Gain 2d h,g because the z-axis orientation is always zero for gaze_n and rotation_n
                // 10.Convert eye images I to gray scale and make histogram equalization, in order to be compatible with other datasets
                cv::Mat output_orig=output;
  				cvtColor( output, output, CV_BGR2GRAY );/// Convert to grayscale
  				equalizeHist( output, output);/// Apply Histogram Equalization
                float gaze[2];
                regressor.predict(eulerAngles,output.data,gaze); 
                //cout << "prediction:(" << gaze[0]* 180.0/M_PI << "," << gaze[1]* 180.0/M_PI << ")" << endl;

  				//ws apostasi mporw na thewrisw to translation_vector me antitheto z-aksona
           		int x,y;
           		x = -tan(gaze[0])*translation_vector.at<double>(2,0) -translation_vector.at<double>(0,0);//in mm's
           		//y = -tan(gaze[1])*translation_vector.at<double>(2,0) - translation_vector.at<double>(1,0);//in mm's
      			

      			y = -translation_vector.at<double>(2,0)/tan(gaze[1]) -translation_vector.at<double>(1,0);


      			cout  << " x is " << x<<", y is " << y<< endl;
      			cout << "theta:"<< gaze[0]* 180.0/M_PI<<",phi:" << gaze[1]* 180.0/M_PI<< endl;

           		y = 4 * y;
           		x = 340/2; //+ 4 * x;
           		pixH = abs(x);//set
           		pixW = abs(y);

           		//pixH is 482573994 and pixW is -1020350720
           		//cout  << " pixW is " << pixW <<", pixH is " << pixH<< endl;
     
                cv_image<bgr_pixel> cimg2(output_orig);

                win.clear_overlay();
                win.set_image(cimg2);
                win.add_overlay(render_face_detections(shapes2d)); 
            }
            

            //Now let's view our face poses on the screen.
            
            //win.clear_overlay();
            //win.set_image(cimg);
            //win.add_overlay(render_face_detections(shapes2d)); 
	    		    
        }
        regressor.close();
    }
    catch(serialization_error& e)
    {
        cout << "You need dlib's default face landmarking model file to run this example." << endl;
        cout << "You can get it from the following URL: " << endl;
        cout << "   http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2" << endl;
        cout << endl << e.what() << endl;
    }
    catch(exception& e)
    {
        cout << e.what() << endl;
    }
}

	

/*
    	vector<Point3d> nose_end_point3D;//Project a 3D point (0,0,1000.0) onto the image plane.
    	vector<Point2d> nose_end_point2D;
    	nose_end_point3D.push_back(Point3d(0,0,1000.0));
     
    	projectPoints(nose_end_point3D, rotation_vector, translation_vector, camera_matrix, dist_coeffs, nose_end_point2D);
*/



//dlib::array<array2d<rgb_pixel> > face_chips;
//extract_image_chips(cimg, get_face_chip_details(shapes), face_chips);
//win.set_image(tile_images(face_chips));	
        
