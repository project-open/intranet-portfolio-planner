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
    costCenterTreeResourceLoadStore: null,
    costCenterTree: null,
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
        me.costCenterTree.on({
            'viewready': me.onCostCenterTreeViewReady,
            'sortchange': me.onCostCenterGridSelectionChange,
            'scope': this
        });

        // Redraw Cost Center load whenever the store has new data
        me.costCenterTreeResourceLoadStore.on({
            'load': me.onCostCenterResourceLoadStoreChange,
            'datachanged': me.onCostCenterResourceLoadStoreChange,
            'scope': this
        });
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.initComponent: Finished');
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

        me.surface.removeAll();
        me.surface.setSize(me.axisEndX, me.surface.height);	// Set the size of the drawing area
        me.drawAxisAuto();							// Draw the top axis

        // Draw CostCenter bars
        var costCenterTreeView = me.costCenterTree.getView();		// The "view" for the GridPanel, containing HTML elements
        var rootNode = me.costCenterTreeResourceLoadStore.getRootNode();
        rootNode.cascadeBy(function(model) {
            var viewNode = costCenterTreeView.getNode(model);		// DIV with costCenter name on the CostCenterGrid for Y coo
            if (viewNode == null) { return; }				// hidden nodes/models don't have a viewNode
            me.drawCostCenterBar(model);
        });

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.redraw: Finished: items='+me.surface.items.length);
    },

    /**
     * Draw a single bar for a cost center
     */
    drawCostCenterBar: function(costCenter) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: Starting');
	// alert('drawCostCenterBar');

        // Calculate auxillary start- and end dates
        var start_date = me.axisStartDate.toISOString().substring(0,10);
        var end_date = me.axisEndDate.toISOString().substring(0,10);
        var startTime = new Date(start_date).getTime();
        var endTime = new Date(end_date).getTime();

        // Calculate the start and end of the cost center bars
        var costCenterTreeView = me.costCenterTree.getView();                                     // The "view" for the GridPanel, containing HTML elements
        var firstCostCenterBBox = costCenterTreeView.getNode(0).getBoundingClientRect();
        var costCenterBBox = costCenterTreeView.getNode(costCenter).getBoundingClientRect();

        // Calculate coordinates for the bar, based on the CostCenterTree
        var ccY = costCenterBBox.top - firstCostCenterBBox.top + 25;
        var ccH = costCenterBBox.height - 4;

        var ccStartX = 0;                                                              // start drawing at the very left of the surface
        var ccW = Math.floor(me.axisEndX * (endTime - startTime) / (me.axisEndDate.getTime() - me.axisStartDate.getTime()));
	var ccEndX = ccStartX + ccW;

        // Granularity
        var oneDayMilliseconds = 1000.0 * 3600 * 24 * 1.0;
        var intervalTimeMilliseconds;

        switch('day') {
        case 'month': intervalTimeMilliseconds = oneDayMilliseconds * 30.0; break;	// One month
        case 'week': intervalTimeMilliseconds = oneDayMilliseconds * 7.0; break;	// One week
        case 'day':  intervalTimeMilliseconds = oneDayMilliseconds * 1.0; break;	// One day
        default:     alert('Undefined granularity: '+me.granularity);
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
            intervalEndTime = intervalStartTime + intervalTimeMilliseconds;
            intervalEndX = me.date2x(intervalEndTime);
            if (intervalEndX > ccEndX) { intervalEndX = ccEndX; }		// Fix the last interval to stop at the bar
	    var intervalW = intervalEndX - intervalStartX;

	    var color = me.costCenterLoad2Color(available, assigned);

            var intervalBar = me.surface.add({
		type: 'rect',
		x: intervalStartX, y: ccY, width: intervalW, height: ccH,
		fill: color,
		stroke: 'blue',
		'stroke-width': 0.3,
            }).show(true);
            intervalBar.model = costCenter;					// Store the task information for the sprite

            // The former end of the interval becomes the start for the next interval
            intervalStartTime = intervalEndTime;
            intervalStartX = intervalEndX;

        }

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: Finished');
    },


    costCenterLoad2Color: function(avail, assig) {
	var me = this;
	var result = "blue";
	if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: avail='+avail+', assig='+assig+' -> '+result);
	return result;
    }
});

