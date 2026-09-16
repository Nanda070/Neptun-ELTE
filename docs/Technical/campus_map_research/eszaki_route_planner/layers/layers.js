var wms_layers = [];
var format_epulet_minusz1_0 = new ol.format.GeoJSON();
var features_epulet_minusz1_0 = format_epulet_minusz1_0.readFeatures(json_epulet_minusz1_0, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_minusz1_0 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_minusz1_0.addFeatures(features_epulet_minusz1_0);var lyr_epulet_minusz1_0 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_minusz1_0, 
                style: style_epulet_minusz1_0,
                title: 'epulet_minusz1'
            });var format_termek_minusz1_1 = new ol.format.GeoJSON();
var features_termek_minusz1_1 = format_termek_minusz1_1.readFeatures(json_termek_minusz1_1, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_minusz1_1 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_minusz1_1.addFeatures(features_termek_minusz1_1);var lyr_termek_minusz1_1 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_minusz1_1, 
                style: style_termek_minusz1_1,
                title: 'termek_minusz1'
            });var format_epulet_00_2 = new ol.format.GeoJSON();
var features_epulet_00_2 = format_epulet_00_2.readFeatures(json_epulet_00_2, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_00_2 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_00_2.addFeatures(features_epulet_00_2);var lyr_epulet_00_2 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_00_2, 
                style: style_epulet_00_2,
                title: 'epulet_00'
            });var format_termek_00_3 = new ol.format.GeoJSON();
var features_termek_00_3 = format_termek_00_3.readFeatures(json_termek_00_3, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_00_3 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_00_3.addFeatures(features_termek_00_3);var lyr_termek_00_3 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_00_3, 
                style: style_termek_00_3,
                title: 'termek_00'
            });var format_epulet_01_4 = new ol.format.GeoJSON();
var features_epulet_01_4 = format_epulet_01_4.readFeatures(json_epulet_01_4, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_01_4 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_01_4.addFeatures(features_epulet_01_4);var lyr_epulet_01_4 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_01_4, 
                style: style_epulet_01_4,
                title: 'epulet_01'
            });var format_termek_01_5 = new ol.format.GeoJSON();
var features_termek_01_5 = format_termek_01_5.readFeatures(json_termek_01_5, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_01_5 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_01_5.addFeatures(features_termek_01_5);var lyr_termek_01_5 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_01_5, 
                style: style_termek_01_5,
                title: 'termek_01'
            });var format_epulet_02_6 = new ol.format.GeoJSON();
var features_epulet_02_6 = format_epulet_02_6.readFeatures(json_epulet_02_6, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_02_6 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_02_6.addFeatures(features_epulet_02_6);var lyr_epulet_02_6 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_02_6, 
                style: style_epulet_02_6,
                title: 'epulet_02'
            });var format_termek_02_7 = new ol.format.GeoJSON();
var features_termek_02_7 = format_termek_02_7.readFeatures(json_termek_02_7, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_02_7 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_02_7.addFeatures(features_termek_02_7);var lyr_termek_02_7 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_02_7, 
                style: style_termek_02_7,
                title: 'termek_02'
            });var format_epulet_03_8 = new ol.format.GeoJSON();
var features_epulet_03_8 = format_epulet_03_8.readFeatures(json_epulet_03_8, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_03_8 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_03_8.addFeatures(features_epulet_03_8);var lyr_epulet_03_8 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_03_8, 
                style: style_epulet_03_8,
                title: 'epulet_03'
            });var format_termek_03_9 = new ol.format.GeoJSON();
var features_termek_03_9 = format_termek_03_9.readFeatures(json_termek_03_9, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_03_9 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_03_9.addFeatures(features_termek_03_9);var lyr_termek_03_9 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_03_9, 
                style: style_termek_03_9,
                title: 'termek_03'
            });var format_epulet_04_10 = new ol.format.GeoJSON();
var features_epulet_04_10 = format_epulet_04_10.readFeatures(json_epulet_04_10, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_04_10 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_04_10.addFeatures(features_epulet_04_10);var lyr_epulet_04_10 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_04_10, 
                style: style_epulet_04_10,
                title: 'epulet_04'
            });var format_termek_04_11 = new ol.format.GeoJSON();
var features_termek_04_11 = format_termek_04_11.readFeatures(json_termek_04_11, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_04_11 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_04_11.addFeatures(features_termek_04_11);var lyr_termek_04_11 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_04_11, 
                style: style_termek_04_11,
                title: 'termek_04'
            });var format_epulet_05_12 = new ol.format.GeoJSON();
var features_epulet_05_12 = format_epulet_05_12.readFeatures(json_epulet_05_12, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_05_12 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_05_12.addFeatures(features_epulet_05_12);var lyr_epulet_05_12 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_05_12, 
                style: style_epulet_05_12,
                title: 'epulet_05'
            });var format_termek_05_13 = new ol.format.GeoJSON();
var features_termek_05_13 = format_termek_05_13.readFeatures(json_termek_05_13, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_05_13 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_05_13.addFeatures(features_termek_05_13);var lyr_termek_05_13 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_05_13, 
                style: style_termek_05_13,
                title: 'termek_05'
            });var format_epulet_06_14 = new ol.format.GeoJSON();
var features_epulet_06_14 = format_epulet_06_14.readFeatures(json_epulet_06_14, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_06_14 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_06_14.addFeatures(features_epulet_06_14);var lyr_epulet_06_14 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_epulet_06_14, 
                style: style_epulet_06_14,
                title: 'epulet_06'
            });var format_termek_06_15 = new ol.format.GeoJSON();
var features_termek_06_15 = format_termek_06_15.readFeatures(json_termek_06_15, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_06_15 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_06_15.addFeatures(features_termek_06_15);var lyr_termek_06_15 = new ol.layer.Vector({
                declutter: true,
                source:jsonSource_termek_06_15, 
                style: style_termek_06_15,
                title: 'termek_06'
            });var format_epulet_07_16 = new ol.format.GeoJSON();
var features_epulet_07_16 = format_epulet_07_16.readFeatures(json_epulet_07_16, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_epulet_07_16 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_epulet_07_16.addFeatures(features_epulet_07_16);
var lyr_epulet_07_16 = new ol.layer.Vector({
                //declutter: true,
                source:jsonSource_epulet_07_16, 
                style: style_epulet_07_16,
				title: "7.ep"
            });
var format_termek_07_17 = new ol.format.GeoJSON();
var features_termek_07_17 = format_termek_07_17.readFeatures(json_termek_07_17, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_termek_07_17 = new ol.source.Vector({
    attributions: [new ol.Attribution({html: '<a href=""></a>'})],
});
jsonSource_termek_07_17.addFeatures(features_termek_07_17);
var lyr_termek_07_17 = new ol.layer.Vector({
                //declutter: true,
                source:jsonSource_termek_07_17, 
                style: style_termek_07_17,
				title:"7.terem"
            });
lyr_termek_minusz1_1.setVisible(true);lyr_epulet_00_2.setVisible(true);lyr_termek_00_3.setVisible(true);lyr_epulet_01_4.setVisible(true);lyr_termek_01_5.setVisible(true);lyr_epulet_02_6.setVisible(true);lyr_termek_02_7.setVisible(true);lyr_epulet_03_8.setVisible(true);lyr_termek_03_9.setVisible(true);lyr_epulet_04_10.setVisible(true);lyr_termek_04_11.setVisible(true);lyr_epulet_05_12.setVisible(true);lyr_termek_05_13.setVisible(true);lyr_epulet_06_14.setVisible(true);lyr_termek_06_15.setVisible(true);lyr_epulet_07_16.setVisible(true);lyr_termek_07_17.setVisible(true);
var group_7 = new ol.layer.Group({
                                layers: [lyr_epulet_07_16,lyr_termek_07_17],
                                title: "7. emelet",
                                level: 7,
                                type: 'base',
								combine: true,
								visible: false});
var group_6 = new ol.layer.Group({
                                layers: [lyr_epulet_06_14,lyr_termek_06_15],
                                title: "6. emelet",
                                level: 6,
                                type: 'base',
								combine: true,
								visible: false});
var group_5 = new ol.layer.Group({
                                layers: [lyr_epulet_05_12,lyr_termek_05_13],
                                title: "5. emelet",
                                level: 5,
                                type: 'base',
								combine: true,
								visible: false});
var group_4 = new ol.layer.Group({
                                layers: [lyr_epulet_04_10,lyr_termek_04_11],
                                title: "4. emelet",
                                level: 4,
                                type: 'base',
								combine: true,
								visible: false});
var group_3 = new ol.layer.Group({
                                layers: [lyr_epulet_03_8,lyr_termek_03_9],
                                title: "3. emelet",
                                level: 3,
                                type: 'base',
								combine: true,
								visible: false});
var group_2 = new ol.layer.Group({
                                layers: [lyr_epulet_02_6,lyr_termek_02_7],
                                title: "2. emelet",
                                level: 2,
                                type: 'base',
								combine: true,
								visible: false});
var group_1 = new ol.layer.Group({
                                layers: [lyr_epulet_01_4,lyr_termek_01_5],
                                title: "1. emelet",
                                level: 1,
                                type: 'base',
								combine: true,
								visible: false});
var group_0 = new ol.layer.Group({
                                layers: [lyr_epulet_00_2,lyr_termek_00_3],
                                title: "Földszint",
                                level: 0,
                                type: 'base',
								combine: true,
								visible: true});
var group_minusz1 = new ol.layer.Group({
                                layers: [lyr_epulet_minusz1_0,lyr_termek_minusz1_1],
                                title: "-1. emelet",
                                level: -1,
                                type: 'base',
								combine: true,
								visible: false});


var layersList = [group_minusz1,group_0,group_1,group_2,group_3,group_4,group_5,group_6,group_7];

