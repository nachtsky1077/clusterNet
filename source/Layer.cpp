#include <Layer.h>
#include <basicOps.cuh>



using std::cout;
using std::endl;
using std::string;
using std::vector;

Layer::Layer(int unitcount, int start_batch_size, Unittype_t unit, ClusterNet *gpu){ init(unitcount, start_batch_size,unit,gpu); }
Layer::Layer(int unitcount, Unittype_t unit){ init(unitcount, 0,unit, NULL); }
Layer::Layer(int unitcount){ init(unitcount, 0,Rectified_Linear, NULL); }

Layer::Layer(int unitcount, int start_batch_size, Unittype_t unit, Layer *prev, ClusterNet *gpu)
{ init(unitcount, start_batch_size,unit,gpu); prev->link_with_next_layer(this); }
Layer::Layer(int unitcount, Unittype_t unit, Layer *prev){ init(unitcount, 0,unit, NULL); prev->link_with_next_layer(this); }
Layer::Layer(int unitcount, Layer *prev){ init(unitcount, 0,Rectified_Linear, NULL); prev->link_with_next_layer(this); }

void Layer::init(int unitcount, int start_batch_size, Unittype_t unit, ClusterNet *gpu)
{
	next = NULL;
	prev = NULL;
	w_next = NULL;
	b_next = NULL;
	w_rms_next = NULL;
	b_rms_next = NULL;
	w_grad_next = NULL;
	b_grad_next = NULL;

	target = NULL;
	target_matrix = NULL;
	error = NULL;

	LEARNING_RATE = 0.003;
	RMSPROP_MOMENTUM = 0.9f;
	UNIT_TYPE = unit;
	DROPOUT = 0.5f;
	UNITCOUNT = unitcount;
	BATCH_SIZE = start_batch_size;
	RUNNING_ERROR = 0.0f;
	RUNNING_SAMPLE_SIZE = 0.0f;

	UPDATE_TYPE = RMSProp;
	COST = Misclassification;

	GPU = gpu;

	if(BATCH_SIZE > 0)
	{
		out = zeros(BATCH_SIZE, UNITCOUNT);
		bias_activations = ones(1, BATCH_SIZE);
	}
	else
	{
		out = NULL;
		bias_activations = NULL;
	}

}

void Layer::link_with_next_layer(Layer *next_layer)
{
	next = next_layer;
	if(next->BATCH_SIZE == 0){ next->BATCH_SIZE = BATCH_SIZE; }
	if(!next->GPU){next->GPU = GPU;}

	Matrix *w = GPU->uniformSqrtWeight(UNITCOUNT,next_layer->UNITCOUNT);
	w_next = w;
	w_grad_next = zeros(UNITCOUNT,next_layer->UNITCOUNT);
	w_rms_next = zeros(UNITCOUNT,next_layer->UNITCOUNT);

	Matrix *b = zeros(1,next_layer->UNITCOUNT);
	b_next = b;
	b_grad_next = zeros(1,next_layer->UNITCOUNT);
	b_rms_next = zeros(1,next_layer->UNITCOUNT);


	next->out = zeros(BATCH_SIZE, next->UNITCOUNT);
	next->error = zeros(BATCH_SIZE, next->UNITCOUNT);
	next->bias_activations = ones(1, BATCH_SIZE);
	next->prev = this;
}


void Layer::activation(Matrix *input)
{
	switch(UNIT_TYPE)
	{
		case Logistic:
			logistic(out,out);
			break;
		case Rectified_Linear:
			rectified_linear(out,out);
			break;
		case Softmax:
			softmax(out,out);
			break;
		case Double_Rectified_Linear:
			doubleRectifiedLinear(out,out);
			break;
		case Linear:
			break;
	}


}

void Layer::activation_gradient()
{

	switch(UNIT_TYPE)
	{
		case Logistic:
			logisticGrad(out,out);
			break;
		case Rectified_Linear:
			rectified_linear_derivative(out,out);
			break;
		case Double_Rectified_Linear:
			double_rectified_linear_derivative(out,out);
			break;
		case Softmax:
			break;
		default:
			throw "Unknown unit";
			break;
	}

}

void Layer::handle_offsize()
{
	if(prev->out->rows != out->rows && (!out_offsize || out_offsize->rows != prev->out->rows))
	{
		if(out_offsize)
		{
			cudaFree(out_offsize->data);
			cudaFree(error_offsize->data);
			cudaFree(bias_activations_offsize->data);
			cudaFree(target_matrix_offsize->data);
		}

		out_offsize = empty(prev->out->rows, UNITCOUNT);
		error_offsize = empty(prev->out->rows, UNITCOUNT);
		bias_activations_offsize = empty(1,prev->out->rows);
		target_matrix_offsize = zeros(prev->out->rows, UNITCOUNT);
	}


	if(prev->out->rows != out->rows)
	{
		Matrix *swap;
		swap = out; out = out_offsize; out_offsize = swap;
		swap = error; error = error_offsize; error_offsize = swap;
		swap = bias_activations; bias_activations = bias_activations_offsize; bias_activations_offsize = swap;
		swap = target_matrix; target_matrix = target_matrix_offsize; target_matrix_offsize = swap;
	}

}



void Layer::forward()
{
	if(!prev){ next->forward(); next->running_error(); return; }
	handle_offsize();

	GPU->dot(prev->out,prev->w_next,out);
	addMatrixVector(out,prev->b_next,out);
    activation(out);

    if(next != 0)
    	next->forward();
}


void Layer::running_error()
{
	if(!target){ next->running_error(); return;}

	string text = "";

	Matrix *result;
	Matrix *eq;
	float sum_value = 0.0f;

	switch(COST)
	{
		case Misclassification:
			result = argmax(out);
			eq = equal(result,target);
			sum_value = sum(eq);
			RUNNING_ERROR += (out->rows  - sum_value);
			RUNNING_SAMPLE_SIZE += out->rows;
			break;
		default:
			throw "Unknown cost function!";
			break;
	}

	cudaFree(result->data);
	cudaFree(eq->data);
}



void Layer::backward()
{
	if(!target){ next->backward(); }
	if(target)
	{
		if(out->cols != target->cols && !target_matrix){ target_matrix = zeros(BATCH_SIZE,out->cols); }
		if(out->cols != target->cols){ create_t_matrix(target,target_matrix); sub(out,target_matrix,error); return; }
		else{ sub(out,target,error);  return;}
	}

	GPU->Tdot(out, next->error, w_grad_next);
	GPU->dot(next->bias_activations, next->error,b_grad_next);

	if(UNIT_TYPE == Input){ return; }

	activation_gradient();
	GPU->dotT(next->error, w_next,error);
	mul(error, out, error);

}

void Layer::weight_update()
{
	if(target){ return; }

	next->weight_update();

	switch(UPDATE_TYPE)
	{
		case RMSProp:
			//cout << sum(w_next) << endl;
			RMSprop_with_weight_update(w_rms_next,w_grad_next,w_next,w_next,RMSPROP_MOMENTUM,LEARNING_RATE,out->rows,MOMENTUM);
			//cout << sum(w_next) << endl;
			break;
		default:
			throw "Unknown update type!";
			break;
	}


}

void Layer::print_error(string message)
{
	if(!target){ next->print_error(message); return;}

	cout << message << RUNNING_ERROR/RUNNING_SAMPLE_SIZE << endl;
	RUNNING_ERROR = 0.0f;
	RUNNING_SAMPLE_SIZE = 0.0f;
}

Layer::~Layer()
{
	cout << "destruct" << endl;
}


