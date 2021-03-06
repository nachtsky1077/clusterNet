#ifndef BatchAllocator_H
#define BatchAllocator_H

#include <cublas_v2.h>
#include <basicOps.cuh>
#include <curand.h>
#include <mpi.h>
#include <list>
#include <string>
#include <clusterNet.h>
#include <cuda_runtime_api.h>
#include <Layer.h>


typedef enum BatchAllocationMethod_t
{
	Single_GPU = 0,
	Batch_split = 1,
	Distributed_weights = 2,
	Distributed_weights_sparse = 4
} BatchAllocationMethod_t;

class BatchAllocator
{

public:
	 BatchAllocator();
	 BatchAllocationMethod_t BATCH_METHOD;
	 Matrix *CURRENT_BATCH;
	 Matrix *CURRENT_BATCH_Y;
	 Matrix *CURRENT_BATCH_CV;
	 Matrix *CURRENT_BATCH_CV_Y;
	 int TOTAL_BATCHES;
	 int TOTAL_BATCHES_CV;
	 int BATCH_SIZE;
	 int BATCH_SIZE_CV;
	 int TRAIN_SET_ROWS;
	 int CV_SET_ROWS;

	 bool SKIP_LAST_BATCH;

	 void finish_batch_allocator();
	 void broadcast_batch_to_processes();
	 void broadcast_batch_cv_to_processes();
	 void allocate_next_batch_async();
	 void allocate_next_cv_batch_async();
	 void replace_current_batch_with_next();
	 void replace_current_cv_batch_with_next();

	 void init(Matrix *X, Matrix *y, float cross_validation_size, int batch_size, int cv_batch_size, ClusterNet *cluster, BatchAllocationMethod_t batchmethod);
	 void init(std::string path_X, std::string path_y, float cross_validation_size, int batch_size, int cv_batch_size, ClusterNet *cluster, BatchAllocationMethod_t batchmethod);
	 void init(Matrix *X, Matrix *y, float cross_validation_size, int batch_size, int cv_batch_size);

	 void propagate_through_layers(Layer *root, DataPropagationType_t type, int epoch);

	 int m_next_batch_number_cv;
private:
	 Matrix *m_next_batch_X;
	 Matrix *m_next_batch_y;
	 Matrix *m_next_batch_cv_X;
	 Matrix *m_next_batch_cv_y;
	 Matrix *m_full_X;
	 Matrix *m_full_y;

	 Matrix* m_next_buffer_X;
	 Matrix* m_next_buffer_y;
	 Matrix* m_next_buffer_cv_X;
	 Matrix* m_next_buffer_cv_y;

	 int m_next_batch_number;
	 int m_Cols_X;
	 int m_Cols_y;
	 int m_Rows;
	 int m_mygpuID;
	 int m_myrank;

	 int m_sparse_matrix_info_X[6];
	 int m_sparse_matrix_info_y[6];
	 int m_sparse_matrix_info_cv_X[6];
	 int m_sparse_matrix_info_cv_y[6];

	 ClusterNet *m_cluster;
	 MPI_Status m_status;

	 cudaStream_t m_streamNext_batch_X;
	 cudaStream_t m_streamNext_batch_y;
	 cudaStream_t m_streamNext_batch_cv_X;
	 cudaStream_t m_streamNext_batch_cv_y;

	 std::vector<MPI_Request> m_requests_send_X;
	 std::vector<MPI_Request> m_requests_send_y;
	 std::vector<MPI_Request> m_requests_send_cv_X;
	 std::vector<MPI_Request> m_requests_send_cv_y;

	 std::vector<MPI_Request>  m_request_X;
	 std::vector<MPI_Request>  m_request_y;
	 std::vector<MPI_Request>  m_request_cv_X;
	 std::vector<MPI_Request>  m_request_cv_y;

	 void MPI_get_dataset_dimensions();
	 void init(float cross_validation_size, int batch_size, int cv_batch_size);
	 void init_batch_buffer();
	 void init_copy_to_buffer();
	 void update_next_batch_matrix_info();
	 void update_next_cv_batch_matrix_info();


};
#endif


