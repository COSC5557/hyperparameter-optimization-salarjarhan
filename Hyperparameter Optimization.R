# Load libraries
library(mlr3)
library(mlr3learners)
library(mlr3tuning)
library(mlr3misc)
library(mlr3viz)
library(readr)
library(caret)
library(ggplot2)
library(dplyr)
library(mlr3mbo)
library(bbotk)

# Load the wine quality data from a CSV file
wine_data <- read.csv("winequality-white.csv", sep = ";")

# For reproducibility
set.seed(123)

# Split the data into a training set and a testing set
train_index <- createDataPartition(wine_data$quality, p = 0.8, list = FALSE)
train_data <- wine_data[train_index, ]
test_data <- wine_data[-train_index, ]

# Create a regression Task object
task <- as_task_regr(train_data, target = "quality")
test_task <- as_task_regr(test_data, target = "quality")

# Define regression learners with specified hyperparameters
models <- list(
  lrn("regr.kknn", k = to_tune(lower = 1, upper = 20), distance = to_tune(lower = 1, upper = 20)),  # k-Nearest Neighbors 
  lrn("regr.ranger", num.trees = to_tune(lower = 100, upper = 1000), min.node.size = to_tune(lower = 1, upper = 20), mtry= to_tune(lower = 1, upper = 10)),  # Random Forest
  lrn("regr.svm", type = "eps-regression", kernel = "radial", cost = to_tune(lower = 0.1, upper = 10), epsilon = to_tune(lower = 0.01, upper = 2), gamma = to_tune(lower = 0.01, upper = 2)),  # Support Vector Machine
  lrn("regr.xgboost", nrounds = to_tune(lower = 10, upper = 300), max_depth =  to_tune(lower = 1, upper = 20))  # Gradient Boosting
)

# Train and evaluate models
results <- lapply(models, function(learner) {
  # Single Criterion Tuning
  instance = TuningInstanceSingleCrit$new(
    task = task,
    learner = learner,
    resampling = rsmp("cv", folds = 5),
    measure = msr("regr.rmse"),
    terminator = trm("evals", n_evals = 100),
    store_models = TRUE)
  
  # Selecting the tuner
  tuner = tnr("mbo") 
  #tuner = tnr("grid_search")
  #tuner = tnr("random_search")
  
  set.seed(2906)
  tuner$optimize(instance)
  
  # Return evaluation results
  list(
    learner = learner,
    instance = instance,
    parameters = instance$result
  )
})

# Plot the optimization process 
data1={}
for (i in 1:length(results)) {
  # Extract data from the plot and modify column names
  data <- ggplot_build(autoplot(results[[i]]$instance, type = "performance"))$data[[1]]
  data <- data[, c("x", "y")]
  colnames(data) <- c("iter", "RMSE")
  data$Legend <- paste(results[[i]]$learner$id, i)
  data1[[i]] <- data
}
combined_df <- do.call(rbind, data1)

ggplot(combined_df, aes(x = iter, y = RMSE, color = Legend)) +
  geom_line(size = 1) +
  theme_bw()

# Evaluation of the validation
rmse ={}
for (i in 1:length(results)) {
  # Set optimal hyperparameter configuration to learner
  results[[i]]$learner$param_set$values = results[[i]]$instance$result_learner_param_vals
  results[[i]]$learner$train(task)
  # Predict on the test data
  predictions <- predict(results[[i]]$learner, test_task$data())
  rmse_test <- sqrt(mean((test_data$quality - predictions)^2))
  rmse[[i]] <- rmse_test
}

#References
#https://mlr3mbo.mlr-org.com/dev/articles/mlr3mbo.html#intro
#https://mlr-org.com/tuners.html
#https://mlr-org.com/gallery/technical/2022-12-22-mlr3viz
#https://chat.openai.com/share/675eb339-0d15-4d5d-9b30-452de665b12a

