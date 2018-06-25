#ifdef OLD_HEADER_FILENAME
#include <iostream.h>
#else
#include <iostream>
#endif
using std::cout;
using std::endl;

#include <string>
#include "H5Cpp.h"
using namespace H5;

const H5std_string FILE_NAME( "myfile.h5" );
const int    RANK_OUT = 2;
const int NX = 1;
const int NY = 13;
int main(void)  {
   int curr_nearest[13];
   int rank;
   hsize_t      offset[2];	// hyperslab offset in the file
   hsize_t      count[2];	// size of the hyperslab in the file111
   hsize_t     dimsm[2]; /* memory space dimensions */
   hsize_t offset_out[2];
   hsize_t count_out[2];
   hsize_t dims_out[2];

   H5File *file = NULL;
   Group *group = NULL;

   DataSet dataset;
   DataSpace dataspace;
   /*
    * Try block to detect exceptions raised
    */   
    try {
    
       /*
       * Turn off the auto-printing when failure occurs so that we can
       * handle the errors appropriately
       */
      Exception::dontPrint();
      
      file = new H5File(FILE_NAME, H5F_ACC_RDWR);
      group = new Group(file->openGroup("g1") );   
 
/*
 *****************************************************
      12_nearestIDS
*******************************************************
*/
      dataset = group->openDataSet("12_nearestIDs");     
      dataspace = dataset.getSpace();//dataspace???
      rank = dataspace.getSimpleExtentNdims();//numOfDims
      
      //dataset      
      offset[0] = 0;
      offset[1] = 0;
      count[0]  = 1;
      count[1]  = 13;
      dataspace.selectHyperslab( H5S_SELECT_SET, count, offset );

      //memory database	
      dimsm[0] = 1;
      dimsm[1] = 13;
      DataSpace memspace( RANK_OUT, dimsm );

      //memory hyperslab     
      offset_out[0] = 0;
      offset_out[1] = 0;
      count_out[0] = NX; 
      count_out[1] = NY; 
      memspace.selectHyperslab( H5S_SELECT_SET, count_out, offset_out );
 
      dataset.read(curr_nearest, PredType::NATIVE_INT, memspace, dataspace ); 
      for (int j=0; j < 12; j++)  {
         cout << curr_nearest[j] << ", ";  
      }
      cout << "\n";
/*
 *****************************************************
      center:1x2
*******************************************************
*/
      dataset = group->openDataSet("center");     
      dataspace = dataset.getSpace();//dataspace???
      rank = dataspace.getSimpleExtentNdims();//numOfDims
     








     /*
      * Close the group and file
      */         
      delete group;
      delete file;
       
    } 
    catch(  FileIException error)  {
       error.printErrorStack();    
       return -1;
    }
    
    
    


   return 0;
}
