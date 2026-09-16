var utvonaldoboz=document.getElementById('utvonal');
var szintdoboz=document.getElementById('szint');
szintdoboz.innerHTML='<h2>Földszint</h2>';
var rs=new ol.source.Vector();
var cps=new ol.source.Vector();
var utvonalStyle=new ol.style.Style({
    stroke: new ol.style.Stroke({ color: [0,163,207,.6], width: 2 }),
});

var cpStyle=new ol.style.Style({
    image: new ol.style.Circle({
            radius: 4,
            stroke: new ol.style.Stroke({ color: [255,255,0,255], width: 1 }),
            fill: new ol.style.Fill({ color: [255,255,0,255] })
        }),
    stroke: new ol.style.Stroke({ color: [255,128,0,.6], width: 4 }),
    fill: new ol.style.Fill({ color: [255,128,0,.2] })
});

layersList.push(new ol.layer.Vector({
            title: 'Útvonal',
            displayInLayerSwitcher: false,
            source: rs,
            style: utvonalStyle            
        })
);
layersList.push(new ol.layer.Vector({
            title: 'Aktuális pont',
            source: cps,
            style: cpStyle            
        })
);
// OpenLayers map interface
var map=new ol.Map({
    target: 'map',
    controls: [new ol.control.Zoom(),new ol.control.FullScreen()],
    layers: layersList/*[
           
        new ol.layer.Vector({
            title: 'route',
            source: rs,
            //style: bbStyle            
        }),
        new ol.layer.Vector({
            title: 'currentpoint',
            source: cps,
            //style: bbStyle            
        })
    ]*/,
    view: new ol.View({
        center: ol.proj.transform([19.062, 47.4746], 'EPSG:4326', 'EPSG:3857'),
        zoom: 19
    })        
});

var layerSwitcher = new ol.control.LayerSwitcher({
    tipLabel: 'Layers' // Optional label for button
});
map.addControl(layerSwitcher);

function sqr(x) {
    return x*x;
}

function navihelp(x,y,level,szakasz) {
    var f=new ol.Feature({geometry:new ol.geom.Point([x,y])});
    cps.addFeatures([f]);
    
    if (typeof(szakasz)!="undefined") {
        var f2=new ol.Feature({geometry:new ol.geom.LineString(szakasz)});
        cps.addFeatures([f2]);
    }

	szintdoboz.innerHTML="<h2>"+level+ ". emelet </h2><br/>";
    // csak az aktuális layert mutatja
    var layers=map.getLayers().getArray();

    for (var i=0;i<layers.length;i++)
        if (typeof layers[i].getProperties().level!='undefined')
            layers[i].setVisible(layers[i].getProperties().level==level);

		
		
}

function hidenode() {
    cps.clear();

}
var corr=Math.cos(47.5/180*Math.PI);
function route() {
    rs.clear();
    var id1=document.getElementById('from').value;
    var id2=document.getElementById('to').value;
    var restr=document.getElementById('enableRestricted').checked?0:1;
    var x=new XMLHttpRequest();
    x.open('get','route_eszaki.php?id1='+id1+'&id2='+id2+'&restricted='+restr,false);
    x.send();
    var pts=x.responseText.split('\n');
    if (pts[pts.length-1]=='') // ha az utlosó sor üres, töröljük.
        pts.pop();
    if (pts.length==0) {
        alert ("Hiba! Nincs útvonal a két pont között.");
		utvonaldoboz.innerHTML="";
        return;
    }
    var path=[];
    var pontok=[];
    utvonaldoboz.innerHTML='';
	    
    for (var i=0;i<pts.length;i++) {
        var c=pts[i].split(';');
        //console.log(c);
        path.push([parseFloat(c[0]),parseFloat(c[1]),parseFloat(c[2])]);
        pontok.push(c);
        var f=new ol.Feature({geometry:new ol.geom.Point([parseFloat(c[0]),parseFloat(c[1])])});
        //rs.addFeatures([f]);
    }
    rs.addFeatures([new ol.Feature({geometry:new ol.geom.LineString(path)})]);
    //console.log(path);
	var level=path[0][2];
		 var layers=map.getLayers().getArray();
		for (var i=0;i<layers.length;i++)
        if (typeof layers[i].getProperties().level!='undefined')
            layers[i].setVisible(layers[i].getProperties().level==level);
		szintdoboz.innerHTML="<h2>"+level+ ". emelet </h2><br/>";
		
    var a=((Math.atan2(path[1][0]-path[0][0],path[1][1]-path[0][1]))*180/Math.PI); //irány
	var tav=0;
    var szintvaltas=false;
	utvonaldoboz.innerHTML+="Fordíts hátat az indulási pontnak :) <br/>";
    var szakasz=[path[0]];
    
	for (var i=1;i<pontok.length;i++) {		
        d=Math.sqrt(sqr(path[i][0]-path[i-1][0])+sqr(path[i][1]-path[i-1][1]))*corr;  //0.675145678; //az egyes szakaszok hossza
        tav+=d;
        szakasz.push(path[i]);
        if (i<pontok.length-1)
            var na=(Math.atan2(path[i+1][0]-path[i][0],path[i+1][1]-path[i][1]))*180/Math.PI; // következő irány
        var da=na-a;
        if (da<-180) da+=360;
        if (da>180) da-=360;
        a=na;
        var nh="<span class='routehint' onmouseover='navihelp("+path[i][0]+","+path[i][1]+","+path[i][2]+","+JSON.stringify(szakasz)+")' onmouseout='hidenode()'>"
        
        if (i==pontok.length-1||Math.abs(da)>15||['stairs','elevator'].indexOf(pontok[i][3])>-1) {
            if (Math.round(tav)>0&&(tav>3||(i>1&&i<pontok.length-1)))
                utvonaldoboz.innerHTML+=nh+"Menj előre "+Math.round(tav)+" métert!</span><br/>";
			//utvonaldoboz.innerHTML+="most: "+pontok[i][3]+"<br/>";
            tav=0; //mivel forduló vagy valami jön, a táv 0 lesz
            szakasz=[path[i]];
            e=path[i][2]-path[i-1][2]; //szintkülönbség    
            // fel vagy le
            if (e!=0) {
				if (path[i][2]=="-1"||path[i][2]=="2"||path[i][2]=="3"||path[i][2]=="4"||path[i][2]=="6"||path[i][2]=="7") {
                utvonaldoboz.innerHTML+=nh+"Menj "+(e>0?"fel a ":"le a ")+path[i][2]+". emeletre! </span><br/>";
                continue;
				}
				if (path[i][2]=="0") {
					utvonaldoboz.innerHTML+=nh+"Menj "+(e>0?"fel ":"le ")+"a földszintre! </span><br/>";
                continue;
				}
				if (path[i][2]=="1"||path[i][2]=="5") {
					utvonaldoboz.innerHTML+=nh+"Menj "+(e>0?"fel az ":"le az ")+path[i][2]+". emeletre! </span><br/>";
					continue;
				}
				else {
					alert ("Hiba! Nincs ilyen objektum az adatbázisban.");
					utvonaldoboz.innerHTML="";
					return;
				}
            }

            else
                szintvaltas=false;
            // lépcső jön
            if (pontok[i][3]=="stairs"&&!szintvaltas) {
                // a lépcsőhöz értünk
                szintvaltas=true;
                utvonaldoboz.innerHTML+=nh+"Menj a lépcsőhöz!</span><br/>";
                continue;
            }
			if (pontok[i][3]=="elevator"&&!szintvaltas) {
                // a lifthez értünk
                szintvaltas=true;
                utvonaldoboz.innerHTML+=nh+"Menj a lifthez!</span><br/>";
                continue;
            }
            // vége jön
            if (i==pontok.length-1&&i!=0) {
                utvonaldoboz.innerHTML+=nh+"Megérkeztél a célponthoz. </span><br/>";
                continue;
            }
			
			if (da<-170) //innentől előrehoztam  az egészet, hogy az irányok egyben legyenek
                utvonaldoboz.innerHTML+=nh+"Fordulj vissza!</span><br/>";
            else if (da<-45)
                utvonaldoboz.innerHTML+=nh+"Fordulj balra!</span><br/>";
            else if (da<-15)
                utvonaldoboz.innerHTML+=nh+"Fordulj enyhén balra!</span><br/>";
            else if (da<45) 
                utvonaldoboz.innerHTML+=nh+"Fordulj enyhén jobbra!</span><br/>";
            else if (da<170)
                utvonaldoboz.innerHTML+=nh+"Fordulj jobbra!</span><br/>";
            else
                utvonaldoboz.innerHTML+=nh+"Fordulj vissza!</span><br/>";

        }    		
    }
}
// gépelés közben javaslatok a szövegre
// ib az input doboz objektum
function typingHint(ib) {
    var th=document.getElementById('typinghintbox');
    if (!th) {
        th=document.createElement('div');
        th.id='typinghintbox';
        ib.parentNode.appendChild(th);
    }
    if (ib.value=='') {
        th.style.display='none';
        return;
    }
    th.style.position='absolute';
    th.style.bottom='30px';
    th.style.left=ib.offsetLeft+'px';
    var x=new XMLHttpRequest();
    x.open('get','http://terkeptar.elte.hu/~campusrouting/utvonal/typing_hint.php?id='+ib.value,false);
    x.send();
    var h=JSON.parse(x.responseText);
    //console.log(h);
    if (h.length==0) {
        th.style.display='none';
        return;
    }
    th.innerHTML='';
    for (var i=0;i<h.length;i++) {
        var t='';
        if (h[i].id)
            t+=h[i].id;
        if (h[i].name)
            t+=(t!=''?' - ':'')+h[i].name;
        t+=' ('+h[i].level+'.emelet)';
        var d=document.createElement('div');
        d.innerHTML=t;
        d.onclick=(function(room) {
            return function() {
                ib.value=(room.id?room.id:room.name)+' [gid:'+room.gid+']';
                th.style.display='none';
            }
        })(h[i]);
        th.appendChild(d);
    }
    th.style.display='block';
    //console.log(th);
}



