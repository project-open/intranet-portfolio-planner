/*
 * CostCenterResourceLoadStore.js
 *
 * Copyright (c) 2011 - 2015 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */

/**
 * Store for resource load per cost center.
 */
Ext.define('PortfolioPlanner.store.CostCenterResourceLoadStore', {
    extend:			'Ext.data.Store',
    requires: [
	'Ext.data.Store',
	'PO.model.finance.CostCenter'
    ],
    storeId:			'costCenterResourceLoadStore',
    model:			'PO.model.finance.CostCenter',    // PO.model.portfolio_planner.CostCenterResourceLoadModel,
    remoteFilter:		true,			// Do not filter on the Sencha side
    autoLoad:			false,
    pageSize:			100000,			// Load all cost_centers, no matter what size(?)
    proxy: {
        type:			'rest',			// Standard ]po[ REST interface for loading
        url:			'/intranet-portfolio-planner/cost-center-resource-availability.json',
        timeout:		300000,
        reader: {
            type:		'json',			// Tell the Proxy Reader to parse JSON
            root:		'data',			// Where do the data start in the JSON file?
            totalProperty:	'total'			// Total number of tickets for pagination
        }
    },

    /**
     * Custom load function that accepts a ProjectResourceLoadStore
     * as a parameter with the current start- and end dates of the
     * included projects, overriding the information stored in the
     * ]po[ database.
     */
    loadWithProjectData: function(projectStore, preferenceStore, callback) {
        var me = this;
        console.log('PO.store.portfolio_planner.CostCenterResourceLoadStore.loadWithProjectData: starting');
        console.log(this);

        var proxy = this.getProxy();
        proxy.extraParams = {
            format:             'json',
            granularity:	'week',						// 'week' or 'day'
            report_start_date:	report_start_date,				// When to start
            report_end_date:	report_end_date					// when to end
        };

        // Write the simulation start- and end dates as parameters to the store
        // As a result we will get the resource load with moved projects
        projectStore.each(function(model) {
            var projectId = model.get('project_id');
            var sel = preferenceStore.getPreferenceBoolean('project_selected.' + projectId, true);
            if (!sel) { 
                return; 
            }

            var projectId = model.get('project_id');
            var startDate = model.get('start_date').substring(0,10);
            var endDate = model.get('end_date').substring(0,10);
            proxy.extraParams['start_date.'+projectId] = startDate;
            proxy.extraParams['end_date.'+projectId] = endDate;
        });

        this.load(callback);
        console.log('PO.store.portfolio_planner.CostCenterResourceLoadStore.loadWithProjectData: finished');
    }
});

