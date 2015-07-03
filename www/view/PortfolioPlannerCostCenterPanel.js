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

    preferenceStore: null,

    /**
     * Starts the main editor panel as the right-hand side
     * of a project grid and a cost center grid for the departments
     * of the resources used in the projects.
     */
    initComponent: function() {
        var me = this;
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.initComponent: Starting');
        this.callParent(arguments);

        // Catch the event that the object got moved
        me.on({
            'resize': me.redraw,
            'scope': this
        });

        // Catch the moment when the "view" of the CostCenter grid
        // is ready in order to draw the GanttBars for the first time.
        // The view seems to take a while...
        me.objectPanel.on({
            'viewready': me.onCostCenterGridViewReady,
            'sortchange': me.onCostCenterGridSelectionChange,
            'scope': this
        });

        // Redraw Cost Center load whenever the store has new data
        me.objectStore.on({
            'load': me.onCostCenterResourceLoadStoreChange,
            'scope': this
        });
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.initComponent: Finished');
    },

    /**
     * The data in the CC store have changed - redraw
     */
    onCostCenterResourceLoadStoreChange: function() {
        var me = this;
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterResourceLoadStoreChange: Starting');
        me.redraw();
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterResourceLoadStoreChange: Finished');
    },


    /**
     * The list of cost centers is (finally...) ready to be displayed.
     * We need to wait until this one-time event in in order to
     * set the width of the surface and to perform the first redraw().
     */
    onCostCenterGridViewReady: function() {
        var me = this;
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterGridViewReady: Starting');
        me.redraw();
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterGridViewReady: Finished');
    },

    onCostCenterGridSelectionChange: function() {
        var me = this;
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterGridSelectionChange: Starting');
        me.redraw();
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.onCostCenterGridSelectionChange: Finished');
    },

    /**
     * Draw all Gantt bars
     */
    redraw: function() {
        var me = this;

        if (undefined === me.surface) { return; }
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.redraw: Starting');
        var now = new Date();

        me.surface.removeAll();
        me.surface.setSize(me.ganttSurfaceWidth, me.surface.height);	// Set the size of the drawing area
        me.drawAxis();							// Draw the top axis

        // Draw CostCenter bars
        var costCenterStore = me.objectStore;
        var costCenterGridView = me.objectPanel.getView();		// The "view" for the GridPanel, containing HTML elements
        me.objectStore.each(function(model) {
            var viewNode = costCenterGridView.getNode(model);		// DIV with costCenter name on the CostCenterGrid for Y coo
            if (viewNode == null) { return; }				// hidden nodes/models don't have a viewNode
            me.drawCostCenterBar(model);
        });

        var time = new Date().getTime() - now.getTime();
        console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.redraw: Finished: time='+time+', items='+me.surface.items.length);
    },

    /**
     * Draw a single bar for a cost center
     */
    drawCostCenterBar: function(costCenter) {
        var me = this;
        if (me.debug) { console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: Starting'); }
        var costCenterGridView = me.objectPanel.getView();		// The "view" for the GridPanel, containing HTML elements
        var surface = me.surface;

        // Calculate auxillary start- and end dates
        var start_date = me.axisStartDate.toISOString().substring(0,10);
        var end_date = me.axisEndDate.toISOString().substring(0,10);
        var startTime = new Date(start_date).getTime();
        var endTime = new Date(end_date).getTime();

        // Calculate the start and end of the cost center bars
        var costCenterPanelView = me.objectPanel.getView();                                     // The "view" for the GridPanel, containing HTML elements
        var firstCostCenterBBox = costCenterPanelView.getNode(0).getBoundingClientRect();
        var costCenterBBox = costCenterPanelView.getNode(costCenter).getBoundingClientRect();

        // *************************************************
        // Draw the main bar
        var y = costCenterBBox.top - firstCostCenterBBox.top + 23;
        var h = costCenterBBox.height;
        var x = me.date2x(startTime);
        var w = Math.floor( me.ganttSurfaceWidth * (endTime - startTime) / (me.axisEndDate.getTime() - me.axisStartDate.getTime()));
        var d = Math.floor(h / 2.0) + 1;				// Size of the indent of the super-costCenter bar

        var spriteBar = surface.add({
            type: 'rect',
            x: x, y: y, width: w, height: h,
            // radius: 0,
            fill: 'url(#gradientId)',
            // stroke: 'blue',
            // 'stroke-width': 0.3,
            listeners: {						// Highlight the sprite on mouse-over
//                mouseover: function() { this.animate({duration: 500, to: {'stroke-width': 1.0}}); },
//                mouseout: function()  { this.animate({duration: 500, to: {'stroke-width': 0.3}}); }
            }
        }).show(true);
        spriteBar.model = costCenter;					// Store the task information for the sprite

        // *************************************************
        // Draw availability percentage
        var availableDays = costCenter.get('available_days');		// Array of available days since report_start_date
        if (me.preferenceStore.getPreferenceBoolean('show_dept_available_resources', true)) {
            var maxAvailableDays = parseFloat(""+costCenter.get('assigned_resources'));			// Should be the maximum of availableDays
            var template = new Ext.Template("<div><b>Resource Capacity</b>:<br>{value} out of {maxValue} resources are available in department '{cost_center_name}' between {startDate} and {endDate}.<br></div>");
            me.graphOnGanttBar(spriteBar, costCenter, availableDays, maxAvailableDays * 2.0, new Date(startTime), 'blue', template);
        }

        // *************************************************
        // Draw assignment percentage
        var assignedDays = costCenter.get('assigned_days');
        if (me.preferenceStore.getPreferenceBoolean('show_dept_assigned_resources', true)) {
            var maxAssignedDays = parseFloat(""+costCenter.get('assigned_resources'));
            var template = new Ext.Template("<div><b>Resource Assignment</b>:<br>{value} out of {maxValue} resources are assigned to projects in department '{cost_center_name}' between {startDate} and {endDate}.<br></div>");
            me.graphOnGanttBar(spriteBar, costCenter, assignedDays, maxAssignedDays * 2.0, new Date(startTime), 'brown', template);
        }

        // *************************************************
        // Draw load percentage
        if (me.preferenceStore.getPreferenceBoolean('show_dept_percent_work_load', true)) {
            var len = availableDays.length;
            if (assignedDays.length < len) { len = assignedDays.length; }
            var loadDays = [];
            var maxLoadPercentage = 0;
            for (var i = 0; i < len; i++) {
                if (assignedDays[i] == 0.0) {    // Zero assigned => zero
                    loadDays.push(0);
                    continue;
                }
                if (availableDays[i] == 0.0) {   // Avoid division by zero
                    loadDays.push(0);
                    continue;
                }
                var loadPercentage = Math.round(100.0 * 100.0 * assignedDays[i] / availableDays[i]) / 100.0
                if (loadPercentage > maxLoadPercentage) { maxLoadPercentage = loadPercentage; }
                loadDays.push(loadPercentage);
            }
            var template = new Ext.Template("<div><b>Work Load</b>:<br>The work load is at {value}% out of 100% available in department {cost_center_name} beween {startDate} and {endDate}.<br></div>");
            me.graphOnGanttBar(spriteBar, costCenter, loadDays, maxLoadPercentage * 2.0, new Date(startTime), 'green', template);
        }

        // *************************************************
        // Accumulated Load percentage
        if (me.preferenceStore.getPreferenceBoolean('show_dept_accumulated_overload', true)) {
            var accLoad = 0.0
            var accLoadDays = [];
            var maxAccLoad = 0.0
            for (var i = 0; i < len; i++) {
                var assigned = assignedDays[i];
                var available = availableDays[i];
                accLoad = accLoad + assigned - available;
                if (accLoad < 0.0) { accLoad = 0.0; }
                accLoadDays.push(Math.round(100.0 * accLoad) / 100.0);
                if (accLoad > maxAccLoad) { maxAccLoad = accLoad; }
            }
            var template = new Ext.Template("<div><b>Accumulated Overload</b>:<br>There are {value} days of planned work not yet finished in department {cost_center_name} on {startDate}.<br></div>");
            me.graphOnGanttBar(spriteBar, costCenter, accLoadDays, maxAccLoad * 2.0, new Date(startTime), 'purple', template);
        }
        if (me.debug) { console.log('PO.view.portfolio_planner.PortfolioPlannerCostCenterPanel.drawCostCenterBar: Finished'); }
    }
});

