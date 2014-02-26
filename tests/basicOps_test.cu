#include <stdio.h>
#include <mpi.h>
#include <assert.h>
#include <basicOps.cuh>
#include <math.h>
#include <curand.h>
#include <curand_kernel.h>
#include <util.cuh>
#include <clusterNet.h>

int run_basicOps_test(int argc, char *argv[])
{

  ClusterNet gpu = ClusterNet();

  Matrix *m1 = ones(5,6);
  Matrix *m2 = ones(5,6);
  Matrix *m3 = zeros(5,6);
  Matrix *out = zeros(5,6);
  
  //to_col_major test
  //      0 2    3             
  // m1 = 0 0.83 59.1387  
  //                           
  float m1_data[6] = {0,2,3,0,0.83,59.1387};
  size_t m1_bytes = 2*3*sizeof(float);
  Matrix *m1_cpu = (Matrix*)malloc(sizeof(Matrix));
  m1_cpu->shape[0] = 2;
  m1_cpu->shape[1] = 3;
  m1_cpu->bytes = m1_bytes;
  m1_cpu->size = 6;
  m1_cpu->data = m1_data;

  m1 = to_gpu(m1_cpu,1);
  //to_col_major test
  m1 = to_col_major(m1);
  float *test;
  test = (float*)malloc(m1->bytes);
  cudaMemcpy(test,m1->data,m1->bytes,cudaMemcpyDefault);

  assert(test_eq(test[0], 0.0f,"To col major data."));
  assert(test_eq(test[1], 0.0f,"To col major data."));
  assert(test_eq(test[2], 2.0f,"To col major data."));
  assert(test_eq(test[3], 0.83f,"To col major data."));
  assert(test_eq(test[4], 3.0f,"To col major data."));
  assert(test_eq(test[5], 59.1387f,"To col major data."));

   m1 = to_row_major(m1);
   cudaMemcpy(test,m1->data,m1->bytes,cudaMemcpyDefault);

   assert(test_eq(test[0], 0.0f,"To row major data."));
   assert(test_eq(test[1], 2.0f,"To row major data."));
   assert(test_eq(test[2], 3.0f,"To row major data."));
   assert(test_eq(test[3], 0.0f,"To row major data."));
   assert(test_eq(test[4], 0.83f,"To row major data."));
   assert(test_eq(test[5], 59.1387f,"To row major data."));


  //test to_host
  //data is converted to column major and then back to row major
  Matrix *m_host = to_host(to_gpu(m1_cpu));
  assert(m_host->shape[0]==m1->shape[0]);
  assert(m_host->shape[1]==m1->shape[1]);
  assert(m_host->size==m1->size);
  assert(m_host->bytes==m1->bytes);
  for(int i = 0; i< 5; i++)
  {
    assert(m_host->data[i]==m1_cpu->data[i]);
  }


  //test fill_with
  m1 = ones(5,6);
  m_host = to_host(m1);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==1.0f);
  }

  //test add
  m3 = add(m1,m2);
  m_host = to_host(m3);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==2.0f);
  } 

  //test to_gpu
  m_host =  to_host(add(to_gpu(m_host),to_gpu(m_host)));
  for(int i = 0; i< 30; i++)
  {
    assert(test_eq(m_host->data[i],4.0f,"To gpu data"));
  } 

  //test mul
  m3 = mul(m3,m3);
  m_host = to_host(m3);
  for(int i = 0; i< 30; i++)
  {
    assert(test_eq(m_host->data[i],4.0f,"Multiplication data"));
  } 

  //test sub
  m3 = sub(m3,m1);
  m_host = to_host(m3);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==3.0f);
  } 

  //test div
  m2 = add(m1,m2); //2
  m3 = div(m3,m2);
  m_host = to_host(m3);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==1.5f);
  } 

  //test add with given output Matrix *
  add(m3,m2,out);
  m_host = to_host(out);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==3.5f);
  }

  //test sub with given output Matrix *
  sub(m3,m2,out);
  m_host = to_host(out);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==-0.5f);
  }

  //test mul with given output Matrix *
  mul(m3,m2,out);
  m_host = to_host(out);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==3.0f);
  }

  //test div with given output Matrix *
  div(m3,m2,out);
  m_host = to_host(out);
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==0.75f);
  }
  
  //test exp
  m_host = to_host(gpuExp(zeros(5,6)));
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==1.0f);
  }

  //test scalar mul
  m_host = to_host(scalarMul(ones(5,6),1.83));
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==1.83f);
  }

  //test sqrt
  m_host = to_host(gpuSqrt(scalarMul(ones(5,6),4)));
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==2.0f);
  }

  //test log
  m_host = to_host(gpuLog(scalarMul(ones(5,6),2.0)));
  for(int i = 0; i< 30; i++)
  {   
    assert(m_host->data[i]==log(2.0f));
  }

  //test square
  m_host = to_host(square(scalarMul(ones(5,6),2)));
  for(int i = 0; i< 30; i++)
  {
    assert(m_host->data[i]==4.0f);
  }

  //test blnFaultySizes
  assert(blnFaultySizes(ones(1,3),ones(2,3),ones(2,3))==1);
  assert(blnFaultySizes(ones(1,3),ones(1,3),ones(2,3))==1);
  assert(blnFaultySizes(ones(1,3),ones(1,3),ones(1,3))==0);
  assert(blnFaultySizes(ones(3,3),ones(3,3),ones(3,3))==0);
  //test blnFaultyMatrixSizes
  assert(blnFaultyMatrixProductSizes(ones(1,3),ones(1,3),ones(3,3))==1);
  assert(blnFaultyMatrixProductSizes(ones(3,1),ones(1,3),ones(2,2))==1);
  assert(blnFaultyMatrixProductSizes(ones(3,1),ones(1,3),ones(3,3))==0);

  //transpose test
  //column major order
  //      0 2    3
  // m1 = 0 0.83 59.1387
  //
  //test to_gpu with is_col_major = 1
  m_host = to_host(T(to_gpu(m1_cpu)));
  assert(test_eq(m_host->data[0],0.0f,"Transpose data."));
  assert(m_host->data[1]==0.0f);
  assert(m_host->data[2]==2.0f);
  assert(m_host->data[3]==0.83f);
  assert(m_host->data[4]==3.0f);
  assert(m_host->data[5]==59.1387f);
  assert(test_matrix(m_host,3,2));

  //to host and to gpu test
  //      0 2    3
  // m1 = 0 0.83 59.1387
  //
  //to gpu and to host should cancel each other out
  m_host = to_host(to_gpu(m1_cpu));
  assert(m_host->data[0]==0.0f);
  assert(m_host->data[1]==2.0f);
  assert(m_host->data[2]==3.0f);
  assert(m_host->data[3]==0.0f);
  assert(m_host->data[4]==0.83f);
  assert(m_host->data[5]==59.1387f);
  assert(test_matrix(m_host,2,3));

  //to_gpu for col major data test
  //col major data
  float m2_data[6] = {0,0,2,0.83,3,59.1387};
  size_t m2_bytes = 2*3*sizeof(float);
  Matrix *m2_cpu = (Matrix*)malloc(sizeof(Matrix));
  m2_cpu->shape[0] = 2;
  m2_cpu->shape[1] = 3;
  m2_cpu->bytes = m2_bytes;
  m2_cpu->size = 6;
  m2_cpu->data = m2_data;
  m_host = to_host(to_gpu(m2_cpu,1));
  //should be in row major now
  assert(m_host->data[0]==0.0f);
  assert(m_host->data[1]==2.0f);
  assert(m_host->data[2]==3.0f);
  assert(m_host->data[3]==0.0f);
  assert(m_host->data[4]==0.83f);
  assert(m_host->data[5]==59.1387f);
  assert(test_matrix(m_host,2,3));


  //slice rows
  m1 = gpu.rand(10,10);
  m2 = to_host(slice_rows(m1, 2,5));
  m1 = to_host(m1);
  assert(test_matrix(m2,4,10));
  int idx = 0;
  for(int i = 20; i < 60; i++)
  {        
    assert(test_eq(m1->data[i], m2->data[idx], idx, i , "Row slice data"));
    idx++;
  }  

  //slice cols
  m1 = gpu.rand(10,10);
  m2 = to_host(slice_cols(m1, 2,5));
  m1 = to_host(m1);
  idx = 0;
  assert(test_matrix(m2,10,4));


  for(int i = 2; i < 100;i++)
  {
    if(((i % 10) < 6) &&
       ((i % 10) > 1))
    {  
      assert(test_eq(m1->data[i], m2->data[idx], idx, i , "Col slice data"));
      idx++;
    }
  }

  //softmax test
  m1 = softmax(ones(1,10));
  m_host = to_host(m1,1);
  assert(test_matrix(m_host,1,10));
  for(int i = 0; i < m_host->size; i++)
  {
	  assert(test_eq(m_host->data[i],0.1,"Softmax equal test"));
  }

  m1 = softmax(gpu.rand(1,10));
  m_host = to_host(m1,1);
  assert(test_matrix(m_host,1,10));
  float sum = 0;
  for(int i = 0; i < m_host->size; i++)
  {
	  sum += m_host->data[i];
  }

  ASSERT(sum > 0.98, "Softmax row sum equal one");
  ASSERT(sum < 1.02, "Softmax row sum equal one");

  m1 = ones(10,10);
  m2 = ones(10,1);
  //sub matrix vector test: A - v
  m_host= to_host(subMatrixVector(m1,m2));
  assert(test_matrix(m_host,10,10));
  for(int i = 0; i < m_host->size; i++)
  {
	  assert(test_eq(m_host->data[i],0.0f, "Matrix - vector, equal data test"));
  }

  //column major order
  //      0 2    3
  // m1 = 0 0.83 59.1387
  //
  //argmax test
  m1 = argmax(to_gpu(m1_cpu,1));
  m_host = to_host(m1);
  assert(test_matrix(m_host,2,1));
  ASSERT(m_host->data[0] == 2, "Argmax test");
  ASSERT(m_host->data[1] == 2, "Argmax test");

  //create t matrix test
  m1 = scalarMul(ones(10,1),4);
  m1 = create_t_matrix(m1,7);
  m_host = to_host(m1);
  assert(test_matrix(m_host,10,7));
  for(int i = 0; i < m_host->size; i++)
  {
	  if((i % m1->shape[1]) == 4)
	  {
		  assert(test_eq(m_host->data[i],1.0f, "Create t matrix data"));
	  }
	  else
	  {
		  assert(test_eq(m_host->data[i],0.0f, "Create t matrix data"));
	  }
  }

  //equal test
  gpu = ClusterNet(12345);
  ClusterNet gpu2 = ClusterNet(12345);
  m2 = gpu.rand(10,10);
  m1 = gpu2.rand(10,10);
  m_host = to_host(equal(m1,m2));
  assert(test_matrix(m_host,10,10));
  for(int i = 0; i < m_host->size; i++)
  {
	  assert(test_eq(m_host->data[i],1.0f, "Matrix matrix Equal data test"));
  }
  m1 = gpu2.rand(10,10);
  m_host = to_host(equal(m1,m2));
  assert(test_matrix(m_host,10,10));
  for(int i = 0; i < m_host->size; i++)
  {
	  assert(test_eq(m_host->data[i],0.0f, "Matrix matrix Equal data test"));
  }

  //test vector sum
  m1 = ones(10,1);
  m2 = ones(1,10);
  m1 = to_host(vectorSum(m1));
  assert(test_matrix(m1,1,1));
  ASSERT(m1->data[0] == 10.0f, "Vector sum test");
  m1 = to_host(vectorSum(m2));
  ASSERT(m1->data[0]  == 10.0f, "Vector sum test");
  m1 = to_host(vectorSum(scalarMul(m2,1.73)));
  ASSERT(m1->data[0] > 17.29f, "Vector sum test");
  ASSERT(m1->data[0] < 17.31f, "Vector sum test");



  return 0;
}



