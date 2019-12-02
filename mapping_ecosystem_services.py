# -*- coding: utf-8 -*-
"""
/***************************************************************************
 MappingEcosystemServices
                                 A QGIS plugin
 This plugin maps ecosystems
 Generated by Plugin Builder: http://g-sherman.github.io/Qgis-Plugin-Builder/
                              -------------------
        begin                : 2019-10-08
        git sha              : $Format:%H$
        copyright            : (C) 2019 by NaturalGIS
        email                : luis.calisto@hotmail.com
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
"""
from qgis.PyQt.QtCore import QSettings, QTranslator, QCoreApplication, QPersistentModelIndex
from qgis.PyQt.QtGui import QIcon, QStandardItemModel, QStandardItem
from qgis.PyQt.QtWidgets import QAction, QWidget, QTableWidgetItem, QPushButton, QFileDialog, QMessageBox, QProgressBar
from qgis.core import Qgis, QgsProject, QgsFeatureRequest, QgsVectorFileWriter, QgsMessageLog, QgsVectorLayer, QgsLayerTreeLayer, QgsLayerTreeGroup
from qgis.utils import iface


# Initialize Qt resources from file resources.py
from .resources import *
# Import the code for the dialog
from .mapping_ecosystem_services_dialog import MappingEcosystemServicesDialog
import os.path
import webbrowser
from osgeo import ogr, gdal, osr
import processing
from processing.tools import dataobjects
from datetime import datetime


class MappingEcosystemServices:
    """QGIS Plugin Implementation."""

    def __init__(self, iface):
        """Constructor.

        :param iface: An interface instance that will be passed to this class
            which provides the hook by which you can manipulate the QGIS
            application at run time.
        :type iface: QgsInterface
        """
        # Save reference to the QGIS interface
        self.iface = iface
        # initialize plugin directory
        self.plugin_dir = os.path.dirname(__file__)
        # initialize locale
        locale = QSettings().value('locale/userLocale')[0:2]
        locale_path = os.path.join(
            self.plugin_dir,
            'i18n',
            'MappingEcosystemServices_{}.qm'.format(locale))

        if os.path.exists(locale_path):
            self.translator = QTranslator()
            self.translator.load(locale_path)
            QCoreApplication.installTranslator(self.translator)

        # Declare instance attributes
        self.actions = []
        self.menu = self.tr(u'&Mapping Ecosystem Services')

        # Check if plugin was started the first time in current QGIS session
        # Must be set in initGui() to survive plugin reloads
        self.first_start = None

    # noinspection PyMethodMayBeStatic
    def tr(self, message):
        """Get the translation for a string using Qt translation API.

        We implement this ourselves since we do not inherit QObject.

        :param message: String for translation.
        :type message: str, QString

        :returns: Translated version of message.
        :rtype: QString
        """
        # noinspection PyTypeChecker,PyArgumentList,PyCallByClass
        return QCoreApplication.translate('MappingEcosystemServices', message)

    def add_action(
            self,
            icon_path,
            text,
            callback,
            enabled_flag=True,
            add_to_menu=True,
            add_to_toolbar=True,
            status_tip=None,
            whats_this=None,
            parent=None):
        """Add a toolbar icon to the toolbar.

        :param icon_path: Path to the icon for this action. Can be a resource
            path (e.g. ':/plugins/foo/bar.png') or a normal file system path.
        :type icon_path: str

        :param text: Text that should be shown in menu items for this action.
        :type text: str

        :param callback: Function to be called when the action is triggered.
        :type callback: function

        :param enabled_flag: A flag indicating if the action should be enabled
            by default. Defaults to True.
        :type enabled_flag: bool

        :param add_to_menu: Flag indicating whether the action should also
            be added to the menu. Defaults to True.
        :type add_to_menu: bool

        :param add_to_toolbar: Flag indicating whether the action should also
            be added to the toolbar. Defaults to True.
        :type add_to_toolbar: bool

        :param status_tip: Optional text to show in a popup when mouse pointer
            hovers over the action.
        :type status_tip: str

        :param parent: Parent widget for the new action. Defaults None.
        :type parent: QWidget

        :param whats_this: Optional text to show in the status bar when the
            mouse pointer hovers over the action.

        :returns: The action that was created. Note that the action is also
            added to self.actions list.
        :rtype: QAction
        """

        icon = QIcon(icon_path)
        action = QAction(icon, text, parent)
        action.triggered.connect(callback)
        action.setEnabled(enabled_flag)

        if status_tip is not None:
            action.setStatusTip(status_tip)

        if whats_this is not None:
            action.setWhatsThis(whats_this)

        if add_to_toolbar:
            # Adds plugin icon to Plugins toolbar
            self.iface.addToolBarIcon(action)

        if add_to_menu:
            self.iface.addPluginToMenu(
                self.menu,
                action)

        self.actions.append(action)

        return action

    def initGui(self):
        """Create the menu entries and toolbar icons inside the QGIS GUI."""

        icon_path = ':/mapping_ecosystem_services/icon.png'
        self.add_action(
            icon_path,
            text=self.tr(u'Mapping Biocontrol Ecosystem Services'),
            callback=self.run,
            parent=self.iface.mainWindow())

        # will be set False in run()
        self.first_start = True

    def unload(self):
        """Removes the plugin menu item and icon from QGIS GUI."""
        for action in self.actions:
            self.iface.removePluginMenu(
                self.tr(u'&Mapping Biocontrol Ecosystem Services'),
                action)
            self.iface.removeToolBarIcon(action)

    def sourceButtonDelete(self):
        # https://gis.stackexchange.com/questions/305945/qgis-qtableview-or-qtable-widget-in-custom-form
        rows = set()
        for index in self.dlg.source.selectedIndexes():
            rows.add(index.row())

        for row in sorted(rows, reverse=True):
            self.dlg.source.removeRow(row)

    def targetButtonDelete(self):
        rows = set()
        for index in self.dlg.target.selectedIndexes():
            rows.add(index.row())

        for row in sorted(rows, reverse=True):
            self.dlg.target.removeRow(row)

    def sourceRowsAdded(self, a, b, c):
        return
        print(self)
        print(a)
        print(b)
        print(c)

    def getLayers(self):
        layers = QgsProject.instance().layerTreeRoot().children()
        projectLayers = [layer for layer in layers if (isinstance(
            layer, QgsLayerTreeLayer) and layer.layer().type() == 0) and layer.layer().geometryType() == 2]
        try:
            groupedLayers = [layer.findLayers() for layer in layers if (
                isinstance(layer, QgsLayerTreeGroup))]
            projectLayers.extend([layer for layer in groupedLayers[0] if (
                isinstance(layer, QgsLayerTreeLayer) and layer.layer().type() == 0) and layer.layer().geometryType() == 2])
        except:
            pass
        return projectLayers

    def loadLandUseFields(self, a):
        selectedLayerIndex = self.dlg.landUseLayerQbox.currentIndex()
        self.dlg.landUseFieldQbox.clear()
        if selectedLayerIndex > 0:
            layers = self.getLayers()
            selectedLayer = layers[selectedLayerIndex-1].layer()
            fieldnames = [field.name() for field in selectedLayer.fields()]
            self.dlg.landUseFieldQbox.addItem('')
            self.dlg.landUseFieldQbox.addItems(fieldnames)

    def loadLandUseTableData(self, a):
        selectedLayerIndex = self.dlg.landUseLayerQbox.currentIndex()
        if selectedLayerIndex > 0:
            layers = self.getLayers()
            selectedLayer = layers[selectedLayerIndex-1].layer()
            selectedLandUseFieldIndex = self.dlg.landUseFieldQbox.currentIndex()
            if selectedLandUseFieldIndex > 0:
                fields = [field for field in selectedLayer.fields()]
                # I will need the selected field for later
                self.landUseSelectedField = fields[selectedLandUseFieldIndex-1]
                fieldData = set()
                for feature in selectedLayer.getFeatures():
                    fieldData.add(
                        str(feature[self.landUseSelectedField.name()]))
                self.dlg.origin.clear()
                self.dlg.origin.addItems(fieldData)

    def getSelectedLandUseLayer(self):
        selectedLandUse = self.dlg.landUseLayerQbox.currentText()
        if selectedLandUse != '':
            return QgsProject.instance().mapLayersByName(selectedLandUse)[0]
        else:
            return ''

    def getSelectedStudyAreaLayer(self):
        selectedStudyArea = self.dlg.studyAreaLayerQbox.currentText()
        return QgsProject.instance().mapLayersByName(selectedStudyArea)[0]

    def getTargetItems(self):
        items = []
        for row in range(self.dlg.target.rowCount()):
            item = self.dlg.target.item(row, 0)
            text = str(item.text())
            items.append(text)
        return items

    def getSourceItems(self):
        items = []
        values = []
        for row in range(self.dlg.source.rowCount()):
            item = self.dlg.source.item(row, 0)
            value = self.dlg.source.item(row, 1)
            text = str(item.text())
            items.append(text)
            number = float(value.text().replace(',', '.'))
            values.append(number)
        return {"items": items, "values": values}

    def helpAction(self):
        '''Display a help page'''
        webbrowser.open(
            'https://github.com/NaturalGIS/mapping_ecosystem_services', new=2)

    def log(self, message, level=Qgis.Info):
        QgsMessageLog.logMessage(
            message, 'Mapping Ecosystem Services Plugin', level=level)

    def selectFolder(self):
        foldername = QFileDialog.getExistingDirectory(
            self.dlg, "Select folder ", "",)
        self.dlg.searchFolder.setText(foldername)

    def saveLayerIntoPkg(self, layer, file, layerName):
        opts = QgsVectorFileWriter.SaveVectorOptions()
        opts.driverName = "GPKG"
        opts.actionOnExistingFile = QgsVectorFileWriter.CreateOrOverwriteLayer
        opts.layerName = layerName
        error = QgsVectorFileWriter.writeAsVectorFormat(layer=layer,
                                                        fileName=file,
                                                        options=opts)
        return error

    def saveLayerIntoOgrPkg(self, layer, srcDataSource, layerName):
        try:
            output_layer = srcDataSource.CreateLayer(
                layerName, geom_type=layer.GetGeomType(), srs=layer.GetSpatialRef())
        except:
            output_layer = srcDataSource.CreateLayer(
                layerName)
        if output_layer != None:
            defn = layer.GetLayerDefn()
            for i in range(defn.GetFieldCount()):
                output_layer.CreateField(defn.GetFieldDefn(i))

            # Copying the features
            for feat in layer:
                output_layer.CreateFeature(feat)

    def run(self):
        """Run method that performs all the real work"""

        # Create the dialog with elements (after translation) and keep reference
        # Only create GUI ONCE in callback, so that it will only load when the plugin is started
        if self.first_start == True:
            self.first_start = False
            self.dlg = MappingEcosystemServicesDialog()
            self.dlg.helpButton.pressed.connect(self.helpAction)
            self.dlg.outputFolderButton.pressed.connect(self.selectFolder)
            self.dlg.sourceDeleteButton.clicked.connect(
                self.sourceButtonDelete)
            self.dlg.targetDeleteButton.clicked.connect(
                self.targetButtonDelete)

        # show the dialog
        self.dlg.show()
        self.dlg.formulaQBox.clear()
        self.dlg.formulaQBox.addItems(['Linear', 'Gaussian'])
        self.dlg.searchFolder.clear()

        ############## Load layers ######################
        # Fetch Study area
        layers = self.getLayers()
        # only vector layers
        # https://qgis.org/pyqgis/master/core/QgsMapLayerType.html#qgis.core.QgsMapLayerType
        # Clear the contents of the comboBox from previous runs
        self.dlg.studyAreaLayerQbox.clear()
        # Populate the comboBox with names of all vector layers
        self.dlg.studyAreaLayerQbox.addItem('')
        self.dlg.studyAreaLayerQbox.addItems(
            [layer.name() for layer in layers])

        # Fetch Land Use
        self.dlg.landUseLayerQbox.clear()
        self.dlg.landUseFieldQbox.clear()
        self.dlg.origin.clear()
        self.dlg.target.setRowCount(0)
        self.dlg.source.setRowCount(0)
        # Populate the comboBox with names of all vector layers
        self.dlg.landUseLayerQbox.addItem('')
        self.dlg.landUseLayerQbox.addItems(
            [layer.name() for layer in layers])

        self.dlg.landUseLayerQbox.currentIndexChanged.connect(
            self.loadLandUseFields)
        self.dlg.landUseFieldQbox.currentIndexChanged.connect(
            self.loadLandUseTableData)

        ##############################

        self.dlg.source.setColumnCount(2)
        self.dlg.source.setHorizontalHeaderLabels(['Land use', 'Value'])

        # self.dlg.source.model().rowsAboutToBeInserted.connect(self.sourceRowsAdded)
        self.dlg.source.model().rowsAboutToBeInserted.connect(self.sourceRowsAdded)

        #####################################
        # current timestamp usefull for output files
        self.timestamp = str(datetime.now().strftime("%d%m%Y_%H%M%S"))
        # Run the dialog event loop
        result = self.dlg.exec_()
        ################## A progress bar ###################
        # progress = QProgressBar()
        # progress.setMaximum(100)
        # progressMessageBar = iface.messageBar().createMessage("Loading layers ...")
        # progressMessageBar.layout().addWidget(progress)
        # iface.messageBar().pushWidget(progressMessageBar, Qgis.Info)
        # progress.setValue(5)
        ########################################################
        # See if OK was pressed
        if result:
            outputFolder = self.dlg.searchFolder.displayText()
            if outputFolder == '':
                QMessageBox.information(
                    None, "Warning!", "No datasets folder selected. Please select a folder.")
                iface.messageBar().clearWidgets()
                return
            studyAreaLayer = self.getSelectedStudyAreaLayer()
            landUseLayer = self.getSelectedLandUseLayer()
            currentCRSID = 4326
            try:
                currentCRSID = landUseLayer.crs().postgisSrid()
            except:
                try:
                    currentCRSID = QgsProject.instance().crs().postgisSrid()
                except:
                    currentCRSID = 4326

            # print(landUseLayer.source())
            context = dataobjects.createContext()
            context.setInvalidGeometryCheck(QgsFeatureRequest.GeometryNoCheck)
            formulaType = self.dlg.formulaQBox.currentText()
            analysisType = self.dlg.analysisTypeBox.currentText()
            # progressMessageBar.setText('Extracting polygons ...')
            # progress.setValue(10)
            outputFile = "ogr:dbname='" + \
                os.path.join(outputFolder, 'output_result_'+analysisType+'_'+formulaType+'_') + \
                self.timestamp+".gpkg' table=land_use (geom) sql="
            # extract poligons that intersect area of interest
            processing.run("qgis:extractbylocation", {
                           'INPUT': landUseLayer, 'INTERSECT': studyAreaLayer, 'OUTPUT': outputFile, 'PREDICATE': [0]})
            outputFile = os.path.join(outputFolder, 'output_result_'+analysisType+'_'+formulaType+'_') + \
                self.timestamp+".gpkg"

            self.saveLayerIntoPkg(studyAreaLayer, outputFile, 'study_area')

            srcDataSource = ogr.Open(
                os.path.join(outputFolder, 'output_result_'+analysisType+'_'+formulaType+'_') + self.timestamp + '.gpkg', 1)
            # progressMessageBar.setText('Computing values ...')
            # progress.setValue(20)
            sourceItems = self.getSourceItems().get('items')
            sourceValues = self.getSourceItems().get('values')

            if analysisType == 'Boundaries':
                if formulaType == 'Linear':
                    sql = '''
                        with s as (
                            select *, case {landUseField} {caseStatment} end as value
                            from {landUseLayer}
                            where {landUseField} in ({sourceItems})
                        ),
                        t as (
                                select *
                        from {landUseLayer}
                        where {landUseField} in ({targetItems})
                        )
                        SELECT AsWKT(st_ShortestLine(s.geom,t.geom)) as geomText ,t.fid as tfid,s.fid as sfid,t.{landUseField}, st_distance(s.geom,t.geom) as distance, CASE
                                WHEN st_distance(s.geom,t.geom) = 0 then s.value
                                WHEN st_distance(s.geom,t.geom)>0 then (1-(st_distance(s.geom,t.geom)/{maxDistance}))*s.value
                        END as computed
                        FROM s,t
                        where PtDistWithin(s.geom,t.geom,{maxDistance})
                        '''.format(
                        landUseLayer="land_use",
                        studyArea="study_area",
                        landUseField=self.landUseSelectedField.name(),
                        targetItems=', '.join(
                            ['"'+str(x)+'"' for x in self.getTargetItems()]),
                        sourceItems=', '.join(
                            ['"'+str(x)+'"' for x in sourceItems]),
                        # sourceValues=', '.join(
                        #     [str(x) for x in sourceValues]),
                        caseStatment=' '.join(['WHEN "'+x+'" THEN '+str(y) for x, y in [
                            [sourceItems[i], sourceValues[i]] for i in range(0, len(sourceItems))]]),
                        maxDistance=self.dlg.maxDistanceSpinBox.value(),
                        currentCRSID=currentCRSID
                    )
                elif formulaType == 'Gaussian':
                    sql = '''
                        with s as (
                            select *, case {landUseField} {caseStatment} end as value
                            from {landUseLayer}
                            where {landUseField} in ({sourceItems})
                        ),
                        t as (
                                select *
                        from {landUseLayer}
                        where {landUseField} in ({targetItems})
                        )

                        SELECT AsWKT(st_ShortestLine(s.geom,t.geom)) as geomText ,t.fid as tfid,s.fid as sfid,t.{landUseField}, st_distance(s.geom,t.geom) as distance, 
                        s.value*((power(2.718281828459045235360287471352662497757247093699959574966,(((st_distance(s.geom,t.geom)/{maxDistance}) * (st_distance(s.geom,t.geom)/{maxDistance}) * -4) + 0.92)))/sqrt(6.283185307179586476925286766559005768394338798750211641949)) as computed
                        FROM s,t
                        where PtDistWithin(s.geom,t.geom,{maxDistance})
                        '''.format(
                        landUseLayer="land_use",
                        studyArea="study_area",
                        landUseField=self.landUseSelectedField.name(),
                        targetItems=', '.join(
                            ['"'+str(x)+'"' for x in self.getTargetItems()]),
                        sourceItems=', '.join(
                            ['"'+str(x)+'"' for x in sourceItems]),
                        # sourceValues=', '.join(
                        #     [str(x) for x in sourceValues]),
                        caseStatment=' '.join(['WHEN "'+x+'" THEN '+str(y) for x, y in [
                            [sourceItems[i], sourceValues[i]] for i in range(0, len(sourceItems))]]),
                        maxDistance=self.dlg.maxDistanceSpinBox.value(),
                        currentCRSID=currentCRSID
                    )
            elif analysisType == 'Bounding boxes':
                if formulaType == 'Linear':
                    sql = '''
                        with s as (
                            select *, case {landUseField} {caseStatment} end as value, ST_Envelope(geom) as bbox
                            from {landUseLayer}
                            where {landUseField} in ({sourceItems})
                        ),
                        t as (
                                select *, ST_Envelope(geom) as bbox
                        from {landUseLayer}
                        where {landUseField} in ({targetItems})
                        )
                        SELECT AsWKT(st_ShortestLine(s.bbox,t.bbox)) as geomText,AsWKT(s.bbox) as sbbox,AsWKT(t.bbox) as tbbox, t.fid as tfid,s.fid as sfid,t.{landUseField}, st_distance(s.bbox,t.bbox) as distance, CASE
                                WHEN st_distance(s.bbox,t.bbox) = 0 then s.value
                                WHEN st_distance(s.bbox,t.bbox)>0 then (1-(st_distance(s.bbox,t.bbox)/{maxDistance}))*s.value
                        END as computed
                        FROM s,t
                        where PtDistWithin(s.bbox,t.bbox,{maxDistance})
                        '''.format(
                        landUseLayer="land_use",
                        studyArea="study_area",
                        landUseField=self.landUseSelectedField.name(),
                        targetItems=', '.join(
                            ['"'+str(x)+'"' for x in self.getTargetItems()]),
                        sourceItems=', '.join(
                            ['"'+str(x)+'"' for x in sourceItems]),
                        # sourceValues=', '.join(
                        #     [str(x) for x in sourceValues]),
                        caseStatment=' '.join(['WHEN "'+x+'" THEN '+str(y) for x, y in [
                            [sourceItems[i], sourceValues[i]] for i in range(0, len(sourceItems))]]),
                        maxDistance=self.dlg.maxDistanceSpinBox.value(),
                        currentCRSID=currentCRSID
                    )
                elif formulaType == 'Gaussian':
                    sql = '''
                        with s as (
                            select *, case {landUseField} {caseStatment} end as value, ST_Envelope(geom) as bbox
                            from {landUseLayer}
                            where {landUseField} in ({sourceItems})
                        ),
                        t as (
                                select *, ST_Envelope(geom) as bbox
                        from {landUseLayer}
                        where {landUseField} in ({targetItems})
                        )

                        SELECT AsWKT(st_ShortestLine(s.bbox,t.bbox)) as geomText,AsWKT(s.bbox) as sbbox,AsWKT(t.bbox) as tbbox,t.fid as tfid,s.fid as sfid,t.{landUseField}, st_distance(s.bbox,t.bbox) as distance, 
                        s.value*((power(2.718281828459045235360287471352662497757247093699959574966,(((st_distance(s.bbox,t.bbox)/{maxDistance}) * (st_distance(s.bbox,t.bbox)/{maxDistance}) * -4) + 0.92)))/sqrt(6.283185307179586476925286766559005768394338798750211641949)) as computed
                        FROM s,t
                        where PtDistWithin(s.bbox,t.bbox,{maxDistance})
                        '''.format(
                        landUseLayer="land_use",
                        studyArea="study_area",
                        landUseField=self.landUseSelectedField.name(),
                        targetItems=', '.join(
                            ['"'+str(x)+'"' for x in self.getTargetItems()]),
                        sourceItems=', '.join(
                            ['"'+str(x)+'"' for x in sourceItems]),
                        # sourceValues=', '.join(
                        #     [str(x) for x in sourceValues]),
                        caseStatment=' '.join(['WHEN "'+x+'" THEN '+str(y) for x, y in [
                            [sourceItems[i], sourceValues[i]] for i in range(0, len(sourceItems))]]),
                        maxDistance=self.dlg.maxDistanceSpinBox.value(),
                        currentCRSID=currentCRSID
                    )
            ResultSet = srcDataSource.ExecuteSQL(sql, dialect='SQLite')
            self.log('saving raw data')
            self.saveLayerIntoOgrPkg(
                ResultSet, srcDataSource, 'raw_data')
            ResultSet = None
            # progressMessageBar.setText('Extracting distance lines ...')
            # progress.setValue(80)
            self.log('Extracting lines')
            sql = '''
            SELECT ST_GeomFromText(a.geomText,{currentCRSID}) as geom, a.tfid as tfid, a.distance as distance, a.geomText, a.sfid, a.{landUseField}, a.computed as computed_value
            FROM {rawData} as a
            where a.distance>0
            '''.format(
                rawData="raw_data",
                currentCRSID=currentCRSID,
                landUseField=self.landUseSelectedField.name()
            )

            ResultSet = srcDataSource.ExecuteSQL(sql, dialect='SQLite')
            self.saveLayerIntoOgrPkg(
                ResultSet, srcDataSource, 'distance_lines')
            ResultSet = None
            self.log('Joinning poligons lines')
            # progressMessageBar.setText(
            #     'Agregating polygon computed values ...')
            # progress.setValue(80)
            sql = '''
                select t.geom as geom, t.fid, sum(r.computed) as computed_value
                from {rawData} as r, {landUseLayer}  as t
                where r.tfid=t.fid
                group by t.fid
            '''.format(
                rawData="raw_data",
                landUseLayer="land_use"
            )
            ResultSet = srcDataSource.ExecuteSQL(sql, dialect='SQLite')
            self.saveLayerIntoOgrPkg(
                ResultSet, srcDataSource, 'computed_poligons')

            rasterResol = self.dlg.outputRasterSizeBox.value()
            # Prepare for Rasterize
            # progressMessageBar.setText('Rasterizing results')
            # progress.setValue(95)
            pixelWidth = pixelHeight = rasterResol
            x_min, x_max, y_min, y_max = ResultSet.GetExtent()
            cols = int((x_max - x_min) / pixelHeight)
            rows = int((y_max - y_min) / pixelWidth)
            rasterPath = os.path.join(
                outputFolder, self.timestamp+'_'+analysisType+'_'+formulaType+'_computed.tif')
            target_ds = gdal.GetDriverByName('GTiff').Create(
                rasterPath, cols, rows, 1, gdal.GDT_Float32)
            target_ds.SetGeoTransform(
                (x_min, pixelWidth, 0, y_min, 0, pixelHeight))
            band = target_ds.GetRasterBand(1)
            band.FlushCache()
            band.SetNoDataValue(0)
            gdal.RasterizeLayer(target_ds, [1], ResultSet, options=[
                'ATTRIBUTE=computed_value', 'noData=0'])
            target_dsSRS = osr.SpatialReference()
            target_dsSRS.ImportFromEPSG(currentCRSID)
            target_ds.SetProjection(target_dsSRS.ExportToWkt())
            band.FlushCache()
            band = None
            target_ds = None
            self.log('Load datasets')
            path_to_gpkg = os.path.join(
                outputFolder, 'output_result_'+analysisType+'_'+formulaType+'_') + self.timestamp + '.gpkg'
            gpkg_distance_layer = path_to_gpkg + "|layername=distance_lines"
            gpkg_polygons_layer = path_to_gpkg + "|layername=computed_poligons"
            vlayer = iface.addVectorLayer(
                gpkg_polygons_layer, "Polygons", "ogr")
            if not vlayer:
                self.log("Layer Polygons failed to load!")
            vlayer = iface.addVectorLayer(
                gpkg_distance_layer, "Distance lines", "ogr")
            if not vlayer:
                self.log("Layer Distance Lines failed to load!")
            vlayer = None
            iface.addRasterLayer(rasterPath, "Computed Values")
            iface.messageBar().clearWidgets()
            self.log('Finalized')
