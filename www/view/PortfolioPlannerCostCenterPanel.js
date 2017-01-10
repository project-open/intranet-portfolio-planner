/*
 * PortfolioPlannerCostCenterPanel.js
 *
 * Copyright (c) 2011 - 2015 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */

/**
 * Like a chart Series, displays a list of cost centers
 * using a kind of Gantt bars.
 */
Ext.define('PortfolioPlanner.view.PortfolioPlannerCostCenterPanel', {
    extend: 'PO.view.gantt.AbstractGanttPanel',
    requires: [
        'PO.view.gantt.AbstractGanttPanel'
    ],

    debug: false,
    objectStore: null,
    objectPanel: null,
    preferenceStore: null,

    /**
     * Starts the main editor panel as the right-hand side
     * of a project grid and a cost center grid for the departments
     * of the resources used in the projects.
     */
    initComponent: function() {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.initComponent: Starting');
        this.callParent(arguments);

        // Catch the moment when the "view" of the CostCenter grid
        // is ready in order to draw the GanttBars for the first time.
        // The view seems to take a while...
        me.objectPanel.on({
            'viewready': me.onCostCenterTreeViewReady,
            'sortchange': me.onCostCenterGridSelectionChange,
            'scope': this
        });

        // Redraw Cost Center load whenever the store has new data
        me.objectStore.on({
            'load': me.onCostCenterResourceLoadStoreChange,
            'datachanged': me.onCostCenterResourceLoadStoreChange,
            'scope': this
        });

        // Listen to vertical scroll events 
        var view = me.objectPanel.getView();
        view.on('bodyscroll',this.onObjectPanelScroll, me);

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.initComponent: Finished');
    },



    /**
     * The user moves the scroll bar of the treePanel at the left.
     * Now scroll the costCenterPanel in the same way.
     */
    onObjectPanelScroll: function(event, view) {
        var me = this;

        var view = me.objectPanel.getView();
        var scroll = view.getEl().getScroll();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onObjectPanelScroll: Starting: '+scroll.top);
        var ganttBarScrollableEl = me.getEl();                       // Ext.dom.Element that enables scrolling
        ganttBarScrollableEl.setScrollTop(scroll.top);
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onObjectPanelScroll: Finished');
    },

    /**
     * The user moves the horizontal scroll bar of the costCenterPanel.
     * Now scroll the projectPanel in the same way.
     */
    onProjectPanelScroll: function(event, view, a, b, c, d) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onProjectPanelScroll: Started');

	var scrollLeft = view.scrollLeft;
        var costCenterPanelScrollableEl = me.getEl();					// Ext.dom.Element that enables scrolling
        costCenterPanelScrollableEl.setScrollLeft(scrollLeft);

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onProjectPanelScroll: Started');
    },


    /**
     * The data in the CC store have changed - redraw
     */
    onCostCenterResourceLoadStoreChange: function() {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterResourceLoadStoreChange: Starting');
        me.redraw();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterResourceLoadStoreChange: Finished');
    },


    /**
     * The list of cost centers is (finally...) ready to be displayed.
     * We need to wait until this one-time event in in order to
     * set the width of the surface and to perform the first redraw().
     */
    onCostCenterTreeViewReady: function() {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterTreeViewReady: Starting');

	// Listen to horizontal scroll events
        var el = me.projectPanel.getEl();
	if (el) {
	    el.on('scroll',me.onProjectPanelScroll, me);
	}

        me.redraw();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterTreeViewReady: Finished');
    },

    onCostCenterGridSelectionChange: function() {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterGridSelectionChange: Starting');
        me.redraw();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterGridSelectionChange: Finished');
    },

    /**
     * Draw all Gantt bars
     */
    redraw: function() {
        var me = this;

        if (undefined === me.surface) { return; }
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.redraw: Starting');

	// Get the root of the ganttTree
        var rootNode = me.objectStore.getRootNode();
	var numNodes = me.nodesInTree(rootNode);
	var surfaceYSize = numNodes * 20;

        me.surface.removeAll();
        me.surface.setSize(me.axisEndX, surfaceYSize);          // Set the size of the drawing area
        me.drawAxisAuto();                                                          // Draw the top axis

        // Draw CostCenter bars
        var objectPanelView = me.objectPanel.getView();				// The "view" for the GridPanel, containing HTML elements
        var rootNode = me.objectStore.getRootNode();
        rootNode.cascadeBy(function(model) {
            var viewNode = objectPanelView.getNode(model);				// DIV with costCenter name on the CostCenterGrid for Y coo
            if (viewNode == null) { return; }						// hidden nodes/models don't have a viewNode
            me.drawCostCenterBar(model);
        });

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.redraw: Finished: items='+me.surface.items.length);
    },

    /**
     * Draw a single bar for a cost center
     */
    drawCostCenterBar: function(costCenter) {
        var me = this;
        //if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: Starting');
        // alert('drawCostCenterBar');

        // Calculate auxillary start- and end dates
        var start_date = me.axisStartDate.toISOString().substring(0,10);
        var end_date = me.axisEndDate.toISOString().substring(0,10);
        var startTime = new Date(start_date).getTime();
        var endTime = new Date(end_date).getTime();

        // Calculate the start and end of the cost center bars
        var objectPanelView = me.objectPanel.getView();				// The "view" for the GridPanel, containing HTML el
        var firstCostCenterBBox = objectPanelView.getNode(0).getBoundingClientRect();
        var costCenterBBox = objectPanelView.getNode(costCenter).getBoundingClientRect();

        // Calculate coordinates for the bar, based on the CostCenterTree
        var ccY = costCenterBBox.top - firstCostCenterBBox.top + 25;
        var ccH = costCenterBBox.height - 4;

        var ccStartX = 0;							// start drawing at the very left of the surface
        var ccW = Math.floor(me.axisEndX * (endTime - startTime) / (me.axisEndDate.getTime() - me.axisStartDate.getTime()));
        var ccEndX = ccStartX + ccW;

        // Granularity
        var oneDayMilliseconds = 1000.0 * 3600 * 24 * 1.0;
        var intervalTimeMilliseconds;

        switch(me.granularity) {
        case 'month': intervalTimeMilliseconds = oneDayMilliseconds * 30.0; break;	// One month
        case 'week': intervalTimeMilliseconds = oneDayMilliseconds * 7.0; break;	// One week
        case 'day':  intervalTimeMilliseconds = oneDayMilliseconds * 1.0; break;	// One day
        default:	 alert('Undefined granularity: '+me.granularity);
        }

        var availableDays = costCenter.get('available_days');
        var assignedDays = costCenter.get('assigned_days');
        var arrayLen = assignedDays.length;

        // Loop through the array
        var intervalStartX = ccStartX;
        var intervalStartTime = startTime;
        for (i = 0; i < arrayLen; i++) {
            var available = availableDays[i];
            var assigned = assignedDays[i];
            var intervalEndTime = intervalStartTime + intervalTimeMilliseconds;
            var intervalEndX = me.date2x(intervalEndTime);
            if (intervalEndX > ccEndX) { intervalEndX = ccEndX; }			// Fix the last interval to stop at the bar
            var intervalW = intervalEndX - intervalStartX;

	    // percentage
	    var perc = 0;
	    if (available > 0) perc = Math.round(assigned * 1000.0 / available) / 10.0;

	    if (available > 0 || assigned > 0) {

		// Determine color + height depending on assignation
		var color = me.costCenterLoad2Color(available, assigned);
		var height = 0;
		if (available != 0) { height = ccH * perc / 100.0; }
		if (height > ccH) height = ccH;
		if (height == 0) height = 0.01;
		
		var intervalBar = me.surface.add({
                    type: 'rect',
                    x: intervalStartX, y: ccY+ (ccH - height), width: intervalW, height: height,
                    fill: color,
                    stroke: 'blue',
                    'stroke-width': 0.3,
		}).show(true);
		intervalBar.model = costCenter;					// Store the cccinformation for sprite
		var html = "<nobr> available days="+available+",<br>assigned days="+assigned+"</nobr>";
		var tip = Ext.create("Ext.tip.ToolTip", { target: intervalBar.el, html: html});	// Tooltip for bar
		if (perc > 100.0) {
		    var text = me.surface.add({
			type: 'text', text: perc+"%", x: intervalStartX+2, y: ccY+ccH/2, fill: '#000', font: "10px Arial"
		    }).show(true);
		    var tip = Ext.create("Ext.tip.ToolTip", { target: text.el, html: html});	// Tooltip for text
		}
	    }

            // The former end of the interval becomes the start for the next interval
            intervalStartTime = intervalEndTime;
            intervalStartX = intervalEndX;

        }

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: Finished');
    },


    costCenterLoad2Color: function(avail, assig) {
        var me = this;

        var blue = "bfd7f9";								// default light blue
	var pink = "ff00ff";								// white

        if (0 == avail && assig > 0) return pink;
        if (0 == avail) return "white";


	var pinkInt = parseInt(pink, 16);
	var blueInt = parseInt(blue, 16);
        var perc = (100.0 * assig / avail) - 90;
	if (perc > 100.0) perc = 100.0;
	if (perc < 0) perc = 0.0;

	var pinkR = pinkInt >> 16 & 255;
	var pinkG = pinkInt >> 8 & 255;
	var pinkB = pinkInt >> 0 & 255;

	var blueR = blueInt >> 16 & 255;
	var blueG = blueInt >> 8 & 255;
	var blueB = blueInt >> 0 & 255;

	var r = (pinkR * perc + blueR * (100-perc)) / 100.0;
	var g = (pinkG * perc + blueG * (100-perc)) / 100.0;
	var b = (pinkB * perc + blueB * (100-perc)) / 100.0;

	var colInt = (Math.floor(r) << 16) + (Math.floor(g) << 8) + (Math.floor(b) << 0);
	var result = colInt.toString(16);
	if (result.length == 4) result = "0"+result;					// padding for r=0
	if (result.length == 5) result = "0"+result;					// padding for r<16
	result = "#"+result;

        // if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostLoad2Color: avail='+avail+', assig='+assig+' -> '+result);
        return result;
    }
});

