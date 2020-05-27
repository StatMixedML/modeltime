context("TEST MODELTIME TABLE")

# Objectives
# - Test Multiple Parsnip Objects
# - Test Multiple Modeltime Objects

# Data
m750 <- m4_monthly %>% filter(id == "M750")

# Split Data 80/20
splits <- initial_time_split(m750, prop = 0.9)


# MODELTIME MODELS ----

# * Auto ARIMA (Parsnip) ----

model_fit_no_boost <- arima_reg() %>%
    set_engine(engine = "auto_arima") %>%
    fit(log(value) ~ date, data = training(splits))

test_that("Auto ARIMA (Parsnip)", {

    # ** Forecast - Parsnip ----
    forecast_tbl <- model_fit_no_boost %>%
        modeltime_forecast(h = "3 years")

    expect_equal(nrow(forecast_tbl), 36)

    # ** Forecast - Modeltime Table ----
    forecast_tbl <- modeltime_table(model_fit_no_boost) %>%
        modeltime_forecast(h = "3 years")

    expect_equal(nrow(forecast_tbl), 36)

    # ** Accuracy - Parsnip ----
    accuracy_tbl <- model_fit_no_boost %>%
        modeltime_accuracy(
            new_data   = testing(splits),
            metric_set = metric_set(rsq, mae)
        )

    expect_equal(nrow(accuracy_tbl), 1)

    # ** Calibrate - Parsnip ----
    calibrated_tbl <- model_fit_no_boost %>%
        modeltime_calibrate(
            new_data   = testing(splits)
        )

    expect_equal(nrow(calibrated_tbl), 1)

    expect_s3_class(calibrated_tbl, "mdl_time_tbl")

    # ** Accuracy - Modeltime ----
    accuracy_tbl <- modeltime_table(model_fit_no_boost) %>%
        modeltime_accuracy(
            new_data   = testing(splits),
            metric_set = metric_set(rsq, mae)
        )

    expect_equal(nrow(accuracy_tbl), 1)

    # ** Calibrate - Modeltime ----
    calibrated_tbl <- modeltime_table(model_fit_no_boost) %>%
        modeltime_calibrate(
            new_data   = testing(splits)
        )

    expect_equal(nrow(calibrated_tbl), 1)

    expect_s3_class(calibrated_tbl, "mdl_time_tbl")

    # ** Refit ----
    future_forecast_tbl <- calibrated_tbl %>%
        modeltime_refit(data = m750) %>%
        modeltime_forecast(h = "3 years")

    expect_equal(future_forecast_tbl$.index[1], ymd("2015-07-01"))
})



# * Auto ARIMA (Workflow) -----

model_spec <- arima_reg() %>%
    set_engine("auto_arima")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_date(date, features = "month") %>%
    step_log(value)

wflw_fit_arima <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))

test_that("Auto ARIMA (Workflow)", {

    # ** Forecast - Workflow ----
    forecast_tbl <- wflw_fit_arima %>%
        modeltime_forecast(h = "3 years")

    expect_equal(nrow(forecast_tbl), 36)

    # ** Forecast - Modeltime Table ----
    forecast_tbl <- modeltime_table(wflw_fit_arima) %>%
        modeltime_forecast(h = "3 years")

    expect_equal(nrow(forecast_tbl), 36)

    # ** Accuracy - Parsnip ----
    accuracy_tbl <- wflw_fit_arima %>%
        modeltime_accuracy(
            new_data   = testing(splits),
            metric_set = metric_set(rsq, mae)
        )

    expect_equal(nrow(accuracy_tbl), 1)

    # ** Accuracy - Modeltime ----
    accuracy_tbl <- modeltime_table(wflw_fit_arima) %>%
        modeltime_accuracy(
            new_data   = testing(splits),
            metric_set = metric_set(rsq, mae)
        )

    expect_equal(nrow(accuracy_tbl), 1)

    # ** Refit ----
    future_forecast_tbl <- wflw_fit_arima %>%
        modeltime_refit(data = m750) %>%
        modeltime_forecast(h = "3 years")

    expect_equal(future_forecast_tbl$.index[1], ymd("2015-07-01"))
})


# MORE MODELTIME MODELS -----

# * ARIMA Boosted (Parsnip) ----

model_fit_boosted <- arima_boost(
    non_seasonal_ar = 0,
    non_seasonal_differences = 1,
    non_seasonal_ma = 1,
    seasonal_ar = 1,
    seasonal_differences = 1,
    seasonal_ma = 1
) %>%
    set_engine(engine = "arima_xgboost") %>%
    fit(log(value) ~ date + as.numeric(date) + month(date, label = TRUE),
        data = training(splits))

test_that("ARIMA Boosted (Parsnip)", {

    expect_s3_class(model_fit_boosted, "_arima_xgboost_fit_impl")

})


# * ETS (Parsnip) ----

model_fit_ets <- exp_smoothing() %>%
    set_engine("ets") %>%
    fit(log(value) ~ date + as.numeric(date) + month(date, label = TRUE),
        data = training(splits))

test_that("ETS (Parsnip)", {

    expect_s3_class(model_fit_ets, "_ets_fit_impl")

})


# * ETS (Workflow) ----

model_spec <- exp_smoothing(
    error  = "multiplicative",
    trend  = "additive",
    season = "multiplicative") %>%
    set_engine("ets")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_log(value)

wflw_fit_ets <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))

test_that("ETS (Workflow)", {

    expect_s3_class(wflw_fit_ets, "workflow")

})



# PARSNIP MODELS ----
# - Shouldn't need tests for these, just using to to create checkpoints
# - Using these in the scale tests

# * LM (Parsnip Model) ----

model_fit_lm <- linear_reg() %>%
    set_engine("lm") %>%
    fit(log(value) ~ as.numeric(date) + month(date, label = TRUE),
        data = training(splits))


# * LM workflow -----

model_spec <- linear_reg() %>%
    set_engine("lm")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_date(date, features = "month") %>%
    step_log(value)

wflw_fit_lm <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))



# * MARS (Parsnip Model) ----

model_fit_mars <- mars(mode = "regression") %>%
    set_engine("earth") %>%
    fit(log(value) ~ as.numeric(date) + month(date, label = TRUE),
        data = training(splits))




# * MARS (Workflow) -----

model_spec <- mars(mode = "regression") %>%
    set_engine("earth")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_date(date, features = "month", ordinal = FALSE) %>%
    step_mutate(date_num = as.numeric(date)) %>%
    step_normalize(date_num) %>%
    step_rm(date) %>%
    step_log(value)

wflw_fit_mars <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))




# * SVM (Parsnip Model) ----

model_fit_svm <- svm_rbf(mode = "regression") %>%
    set_engine("kernlab") %>%
    fit(log(value) ~ as.numeric(date) + month(date, label = TRUE),
        data = training(splits))




# * SVM (Workflow) -----

model_spec <- svm_rbf(mode = "regression") %>%
    set_engine("kernlab")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_date(date, features = "month") %>%
    step_rm(date) %>%
    # SVM requires dummy variables
    step_dummy(all_nominal()) %>%
    step_log(value)

wflw_fit_svm <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))




# * GLMNET (parsnip) ----
# - Not using GLMnet because of requirement for R3.6+

# # Error if penalty value is not included
# model_fit_glmnet <- linear_reg(
#     penalty = 0.000388
#     ) %>%
#     set_engine("glmnet") %>%
#     fit(log(value) ~ as.numeric(date) + month(date, label = TRUE),
#         data = training(splits))
#
# model_fit_glmnet %>%
#     modeltime_accuracy(new_data = testing(splits))
#
#
# # * GLMNET (workflow) ----
#
# model_spec <- linear_reg(penalty = 0.000388) %>%
#     set_engine("glmnet")
#
# recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
#     step_date(date, features = "month") %>%
#     step_mutate(date_num = as.numeric(date)) %>%
#     step_rm(date) %>%
#     step_dummy(all_nominal()) %>%
#     step_log(value)
#
# wflw_fit_glmnet <- workflow() %>%
#     add_recipe(recipe_spec) %>%
#     add_model(model_spec) %>%
#     fit(training(splits))
#
# wflw_fit_glmnet %>% modeltime_accuracy(testing(splits))

# * randomForest (parsnip) ----

model_fit_randomForest <- rand_forest(mode = "regression") %>%
    set_engine("randomForest") %>%
    fit(log(value) ~ as.numeric(date) + month(date, label = TRUE),
        data = training(splits))




# * randomForest (workflow) ----

model_spec <- rand_forest() %>%
    set_engine("randomForest")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_date(date, features = "month") %>%
    step_mutate(date_num = as.numeric(date)) %>%
    step_rm(date) %>%
    step_dummy(all_nominal()) %>%
    step_log(value)

wflw_fit_randomForest <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))



# * XGBoost (parsnip) ----

model_fit_xgboost <- boost_tree(mode = "regression") %>%
    set_engine("xgboost", objective = "reg:squarederror") %>%
    fit(log(value) ~ as.numeric(date) + month(date, label = TRUE),
        data = training(splits))



# * XGBoost (workflow) ----

model_spec <- boost_tree() %>%
    set_engine("xgboost", objective = "reg:squarederror")

recipe_spec <- recipe(value ~ date, data = training(splits)) %>%
    step_date(date, features = "month") %>%
    step_mutate(date_num = as.numeric(date)) %>%
    step_rm(date) %>%
    step_dummy(all_nominal()) %>%
    step_log(value)

wflw_fit_xgboost <- workflow() %>%
    add_recipe(recipe_spec) %>%
    add_model(model_spec) %>%
    fit(training(splits))




# MODELTIME TABLE ----

model_table <- modeltime_table(
    # Modeltime
    model_fit_no_boost,
    wflw_fit_arima,
    model_fit_boosted,
    model_fit_ets,
    wflw_fit_ets,

    # Parsnip
    model_fit_lm,
    wflw_fit_lm,
    model_fit_mars,
    wflw_fit_mars,
    model_fit_svm,
    wflw_fit_svm,
    # model_fit_glmnet,
    # wflw_fit_glmnet,
    model_fit_randomForest,
    wflw_fit_randomForest,
    model_fit_xgboost,
    wflw_fit_xgboost
)

test_that("modeltime_table", {

    expect_error({
        modeltime_table("a")
    })

    expect_s3_class(model_table, "mdl_time_tbl")

    expect_equal(ncol(model_table), 3)

})



# MODELTIME ACCURACY ----

test_that("modeltime_accuracy", {

    expect_error(modeltime_accuracy(1))

    accuracy_tbl <- model_table %>%
        modeltime_accuracy(new_data = testing(splits))

    # Structure
    expect_s3_class(accuracy_tbl, "tbl_df")

    # No missing values
    expect_true(all(!is.na(accuracy_tbl$mae)))

})




# FORECAST ----

test_that("modeltime_forecast", {

    expect_error(modeltime_forecast(1))

    forecast_tbl <- model_table %>%
        modeltime_forecast(
            new_data    = testing(splits),
            actual_data = bind_rows(training(splits), testing(splits))
        )

    # Structure
    expect_s3_class(forecast_tbl, "tbl_df")

    # Correct number of forecasts produced
    expect_equal(
        nrow(forecast_tbl),
        nrow(model_table) * nrow(testing(splits)) + nrow(bind_rows(training(splits), testing(splits)))
    )

})



# REFITTING ----

handlers("progress")
with_progress({
    model_table_refit <- model_table %>%
        modeltime_refit(data = m750)
})

test_that("modeltime_refit", {

    forecast_tbl <- model_table_refit %>%
        modeltime_forecast(
            new_data    = future_frame(m750, date, "3 years"),
            actual_data = m750
        )

    # Refit Structure
    expect_s3_class(model_table_refit, "mdl_time_tbl")

    # Forecast Structure
    expect_s3_class(forecast_tbl, "tbl_df")

    actual_tbl <- forecast_tbl %>% filter(.model_desc == "ACTUAL")
    future_predictions_tbl <- forecast_tbl %>% filter(.model_desc != "ACTUAL")

    expect_true(all(tail(actual_tbl$.index, 1) < future_predictions_tbl$.index))
})


