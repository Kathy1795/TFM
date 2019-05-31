# Paquetes climate4R
library(loadeR)
library(transformeR)
library(downscaleR)
library(randomForest)

# variables utiles
# Se pueden cambiar
ruta = "/home/jovyan/TFM/TFM/"

#No cambiar nada
codigos = matrix(c(sprintf("%06i", 272), sprintf("%06i", 350), sprintf("%06i", 3946), sprintf("%06i", 232), sprintf("%06i", 355), sprintf("%06i", 32), sprintf("%06i", 3991), sprintf("%06i", 2006), sprintf("%06i", 708), sprintf("%06i", 191), sprintf("%06i", 4002), sprintf("%06i", 58), sprintf("%06i", 1686), sprintf("%06i", 62), sprintf("%06i", 450), sprintf("%06i", 333)), nrow=2, ncol=8)
estaciones = c("primavera", "verano", "otoño", "invierno")
for(estacion in estaciones){
    #print(paste("Estacion:",estacion))
    load(paste0(ruta, "data/datosEstaciones/",estacion, "/precip/RF/datos.rda", collapse = ""))
    for(n_vecinos in seq(2,21,2)){
        #print(paste("Nº vecinos:", n_vecinos))
        n_regions = length(dataOccCV)
        modelos = list()
        yOccPredNNRF = list()
        yOccRealNNRF = list()
        yRegPredNNRF = list()
        yRegRealNNRF = list()
        start = Sys.time()
        for(region in 1:n_regions){
            #print(paste("Region:", region))
            modelos[[region]] = list()
            prediccionFoldOcc = c()
            prediccionFoldReg = c()
            realFoldOcc = c()
            realFoldReg = c()
            for(fold in names(dataOccCV[[region]])){
                print(paste("Estacion:",estacion, "Nº vecinos:", n_vecinos, "Region:", region, "Subconjunto:", fold))
                
                if(n_vecinos == 2){
                    startV = Sys.time()
                    dataOccCV[[region]][[fold]][["train"]][["y"]] = subsetStation(dataOccCV[[region]][[fold]][["train"]][["y"]], station.id = codigos[,region])
                    dataOccCV[[region]][[fold]][["test"]][["y"]] = subsetStation(dataOccCV[[region]][[fold]][["test"]][["y"]], station.id = codigos[,region])
                    dataRegCV[[region]][[fold]][["train"]][["y"]] = subsetStation(dataRegCV[[region]][[fold]][["train"]][["y"]], station.id = codigos[,region])
                    dataRegCV[[region]][[fold]][["test"]][["y"]] = subsetStation(dataRegCV[[region]][[fold]][["test"]][["y"]], station.id = codigos[,region])
                    timeElapsedV = Sys.time() - startV
                }
                
                trainOcc = prepareData(dataOccCV[[region]][[fold]][["train"]][["x"]], dataOccCV[[region]][[fold]][["train"]][["y"]], local.predictors = list("n" = n_vecinos, vars = getVarNames(dataOccCV[[region]][[fold]][["train"]][["x"]])))
                
                trainReg = prepareData(dataRegCV[[region]][[fold]][["train"]][["x"]], dataRegCV[[region]][[fold]][["train"]][["y"]], local.predictors = list("n" = n_vecinos, vars = getVarNames(dataRegCV[[region]][[fold]][["train"]][["x"]])))
                
                testOcc = prepareNewData(dataOccCV[[region]][[fold]][["test"]][["x"]], trainOcc)
                realFoldOcc = rbind(realFoldOcc, dataOccCV[[region]][[fold]][["test"]][["y"]][["Data"]])                
                
                testReg = prepareNewData(dataRegCV[[region]][[fold]][["test"]][["x"]], trainReg)
                realFoldReg = rbind(realFoldReg, dataRegCV[[region]][[fold]][["test"]][["y"]][["Data"]])
                
                
                prediccionOcc = c()
                prediccionReg = c()
                modelos[[region]][[fold]] = list()
                modelos[[region]][[fold]][["Occ"]] = list()
                modelos[[region]][[fold]][["Reg"]] = list()
                numeroEstaciones = dim(trainReg[["y"]][["Data"]])[2]
                for(k in 1:numeroEstaciones){
                    dfTrainOcc = data.frame("x"=trainOcc[["x.local"]][[k]][["member_1"]])
                    dfTrainOcc["y"] = as.factor(trainOcc[["y"]][["Data"]][,k])
                    modelos[[region]][[fold]][["Occ"]][[k]] = randomForest(y ~ ., data = dfTrainOcc, ntree = 100)

                    dfTestOcc = data.frame("x" = testOcc[["x.local"]][[k]][["member_1"]])
                    prediccionOcc = cbind(prediccionOcc, as.numeric(predict(modelos[[region]][[fold]][["Occ"]][[k]], dfTestOcc, type="prob")[,2]>0.5))

                    dfTrainReg = data.frame("x"=trainReg[["x.local"]][[k]][["member_1"]])
                    dfTrainReg["y"] = trainReg[["y"]][["Data"]][,k]
                    diasLluvia = which(dfTrainReg["y"] > 1)
                    modelos[[region]][[fold]][["Reg"]][[k]] = randomForest(y ~ ., data = dfTrainReg, subset = diasLluvia, ntree = 100)

                    dfTestReg = data.frame("x" = testReg[["x.local"]][[k]][["member_1"]])
                    prediccionReg = cbind(prediccionReg, predict(modelos[[region]][[fold]][["Reg"]][[k]], dfTestReg))
                }
                prediccionFoldOcc = rbind(prediccionFoldOcc, prediccionOcc)
                prediccionFoldReg = rbind(prediccionFoldReg, prediccionOcc * prediccionReg)
            }
            yOccPredNNRF[[region]] = prediccionFoldOcc
            yOccRealNNRF[[region]] = realFoldOcc
            yRegPredNNRF[[region]] = prediccionFoldReg
            yRegRealNNRF[[region]] = realFoldReg
        }
        timeElapsed = Sys.time() - start + timeElapsedV
        save(modelos, file = paste0(ruta,"data/modelos/",estacion,"/precip/NNRF/NNRF",n_vecinos,".rda", collapse = ""))
        save(yOccPredNNRF, yOccRealNNRF, yRegPredNNRF, yRegRealNNRF, timeElapsed, file = paste0(ruta,"data/resultados/",estacion,"/precip/NNRF/NNRF",n_vecinos,".rda", collapse = ""))
    }
}