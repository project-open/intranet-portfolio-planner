// /intranet-portfolio-planner/www/store/CostCenterTreeResourceLoadStore.js
//
// Copyright (C) 2013 ]project-open[
//
// All rights reserved. Please see
// http://www.project-open.com/license/ for details.

/**
 * Stores the list of CostCenters, together with resource
 * load information for each of them in a given period.
 * The store is used by the ]po[ Portfolio Planner in 
 * order to store the resources available and used per
 * cost center / department.
 */
Ext.define('PortfolioPlanner.store.CostCenterTreeResourceLoadStore', {
    extend:			'Ext.data.TreeStore',
    storeId:			'costCenterTreeResourceLoadStore',
    model:			'PO.model.finance.CostCenter',
    autoload:			false,
    autoSync:			false,          // We need manual control for saving etc.
    folderSort:			false,
    proxy: {
        type:			'ajax',
        url:			'/intranet-portfolio-planner/cost-center-tree-resource-availability.json',
        // extraParams: { cost_center_id:	0 },
        api: {
            read:		'/intranet-portfolio-planner/cost-center-tree-resource-availability.json?read=1',
            create:		'/intranet-portfolio-planner/cost-center-tree-resource-availability-action?action=create',
            update:		'/intranet-portfolio-planner/cost-center-tree-resource-availability-action?action=update',
            destroy:		'/intranet-portfolio-planner/cost-center-tree-resource-availability-action?action=delete'
        },
        reader: {
            type:		'json', 
            rootProperty:	'data' 
        },
        writer: {
            type:		'json', 
            rootProperty:	'data' 
        }
    },

    /**
     * Returns an entry for an id
     */
    getById: function(cc_id) {
	var rootNode = this.getRootNode();
	var resultModel = null;
        rootNode.cascadeBy(function(model) {
	    var id = model.get('id');
	    if (cc_id == id) { 
		resultModel = model; 
	    }
        });
	return resultModel;
    },

    /**
     * Custom load function that accepts a ProjectResourceLoadStore
     * as a parameter with the current start- and end dates of the
     * included projects, overriding the information stored in the
     * ]po[ database.
     */
    loadWithProjectData: function(projectStore, preferenceStore, callback) {
        var me = this;
        console.log('PO.store.portfolio_planner.CostCenterTreeResourceLoadStore.loadWithProjectData: starting');
        console.log(me);

        var proxy = me.getProxy();
        proxy.extraParams = {
            format:             'json',
            granularity:	'week',						// 'week' or 'day'
            report_start_date:	report_start_date,				// When to start
            report_end_date:	report_end_date					// when to end
        };

        // Write the simulation start- and end dates as parameters to the store
        // As a result we will get the resource load with moved projects
	var noProjectSelected = true;
        projectStore.each(function(model) {
            var projectId = model.get('project_id');
            var sel = preferenceStore.getPreferenceBoolean('project_selected.' + projectId, true);
            if (!sel) { return; } else { noProjectSelected = false; }
            var startDate = model.get('start_date').substring(0,10);
            var endDate = model.get('end_date').substring(0,10);
            proxy.extraParams['start_date.'+projectId] = startDate;
            proxy.extraParams['end_date.'+projectId] = endDate;
        });

	if (noProjectSelected) {
	    projectStore.each(function(model) {
		var projectId = model.get('project_id');
		var startDate = model.get('start_date').substring(0,10);
		var endDate = model.get('end_date').substring(0,10);
		proxy.extraParams['start_date.'+projectId] = startDate;
		proxy.extraParams['end_date.'+projectId] = endDate;
            });
	}

        me.load(callback);
        console.log('PO.store.portfolio_planner.CostCenterResourceLoadStore.loadWithProjectData: finished');
    }

});

