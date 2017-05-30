/*
 * ButtonController.js
 *
 * Copyright (c) 2011 - 2014 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */

/**
 * ButtonController
 *
 * Handles button actions in the main button bar.
 */
Ext.define('PortfolioPlanner.controller.ButtonController', {
    extend: 'Ext.app.Controller',
    debug: true,

    resizeController: null,
    projectResourceLoadStore: null,

    init: function() {
        var me = this;
        if (me.debug) { if (me.debug) console.log('PO.controller.gantt_editor.GanttButtonController: init'); }
	
        // Listen to button press events
        this.control({
            '#buttonSave': { click: this.onButtonSave },
            '#buttonMaximize': { click: this.onButtonMaximize },
            '#buttonMinimize': { click: this.onButtonMinimize },
            '#buttonZoomIn': { click: this.onButtonZoomIn },
            '#buttonZoomOut': { click: this.onButtonZoomOut },

	    '#config_menu_show_project_dependencies': {click: this.redraw }, 
	    '#config_menu_show_project_resource_load': {click: this.redraw }, 
	    '#config_menu_show_dept_assigned_resources': {click: this.redraw }, 
	    '#config_menu_show_dept_available_resources': {click: this.redraw }, 
	    '#config_menu_show_dept_percent_work_load': {click: this.redraw }, 
	    '#config_menu_show_dept_accumulated_overload': {click: this.redraw }, 

            scope: me.ganttTreePanel
        });

        return this;
    },

    /**
     * Initiate a complete redraw
     */
    redraw: function() {
	var me = this;
	if (me.debug) { if (me.debug) console.log('PO.controller.gantt_editor.GanttButtonController.redraw: Started'); }

	var showLoad = me.senchaPreferenceStore.getPreferenceBoolean('show_project_resource_load', true);
	if (me.debug) { if (me.debug) console.log('PO.controller.gantt_editor.GanttButtonController.redraw: show_load='+showLoad); }

        me.portfolioPlannerProjectPanel.redraw();
        me.portfolioPlannerCostCenterPanel.redraw();
	if (me.debug) { if (me.debug) console.log('PO.controller.gantt_editor.GanttButtonController.redraw: Finished'); }
    },

    /**
     *
     */
    onButtonSave: function() {
        var me = this;
        // Save the currently modified projects
        Ext.Msg.show({
            title: 'Save Project Schedule?',
            msg: 'We will inform all affected project managers <br>about the changed schedule.',
            buttons: Ext.Msg.OKCANCEL,
            icon: Ext.Msg.QUESTION,
            fn: function(button, text, opt) {
                // Save the store and launch workflows
                if ("ok" == button) {
                    me.projectResourceLoadStore.save({
                        success: function(a,b,c,d,e) {
                            console.log('PO.view.portfolio_planner.ButtonBar: projectResourceLoadStore.save(): success');
			    me.redraw();
                        },
                        failure: function(batch, options) {
                            console.log('PO.view.portfolio_planner.ButtonBar: projectResourceLoadStore.save(): failure');
                            var message = batch.proxy.getReader().jsonData.message;
                            Ext.Msg.alert('Error moving projects', message);
                        }
                    });
                }
            }
        });
    },

    onButtonMinimize: function() {
        var me = this;
	var buttonMaximize = Ext.getCmp('buttonMaximize');
	var buttonMinimize = Ext.getCmp('buttonMinimize');
	buttonMaximize.setVisible(true);
	buttonMinimize.setVisible(false);
	me.resizeController.onSwitchBackFromFullScreen();
    },

    onButtonMaximize: function() {
        var me = this;
	var buttonMaximize = Ext.getCmp('buttonMaximize');
	var buttonMinimize = Ext.getCmp('buttonMinimize');
	buttonMaximize.setVisible(false);
	buttonMinimize.setVisible(true);
	me.resizeController.onSwitchToFullScreen();
    },

    onButtonZoomIn: function() {
        var me = this;
        // Reload the page with the duplicate time interval
        var params = Ext.urlDecode(location.search.substring(1));
        var reportStartTime = new Date(report_start_date).getTime();
        var reportEndTime = new Date(report_end_date).getTime();
        var diffTime = Math.floor((reportEndTime - reportStartTime) / 4);
        var reportStartDate = new Date(reportStartTime + diffTime);
        var reportEndDate = new Date(reportEndTime - diffTime);
        params.report_start_date = reportStartDate.toISOString().substring(0,10);
        params.report_end_date = reportEndDate.toISOString().substring(0,10);
        var url = window.location.pathname + '?' + Ext.Object.toQueryString(params);
        window.location = url;
    },

    onButtonZoomOut: function() {
        var me = this;
        // Reload the page with the duplicate time interval
        var params = Ext.urlDecode(location.search.substring(1));
        var reportStartTime = new Date(report_start_date).getTime();
        var reportEndTime = new Date(report_end_date).getTime();
        var diffTime = Math.floor((reportEndTime - reportStartTime) / 2);
        var reportStartDate = new Date(reportStartTime - diffTime);
        var reportEndDate = new Date(reportEndTime + diffTime);
        params.report_start_date = reportStartDate.toISOString().substring(0,10);
        params.report_end_date = reportEndDate.toISOString().substring(0,10);
        var url = window.location.pathname + '?' + Ext.Object.toQueryString(params);
        window.location = url;
    }
});

