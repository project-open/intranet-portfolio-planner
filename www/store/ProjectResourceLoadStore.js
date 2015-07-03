/*
 * ProjectResourceLoadStore.js
 *
 * Copyright (c) 2011 - 2015 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */

/**
 * Store for the main projects of the portfolio to be managed.
 */
Ext.define('PortfolioPlanner.store.ProjectResourceLoadStore', {
    extend:			'Ext.data.Store',
    requires: [
	'Ext.data.Store',
	'PO.model.project.Project'
    ],
    storeId:			'projectResourceLoadStore',
    model:			'PO.model.project.Project',
    remoteFilter:		true,			// Do not filter on the Sencha side
    autoLoad:			false,
    pageSize:			100000,			// Load all projects, no matter what size(?)
    proxy: {
        type:			'ajax',			// Standard ]po[ REST interface for loading
        url:			'/intranet-portfolio-planner/main-projects-forward-load.json',
        timeout:		300000,
        extraParams: {
            format:             'json',
            start_date:		report_start_date,	// When to start
            end_date:		report_end_date,	// when to end
            granularity:	report_granularity,	// 'week' or 'day'
            project_type_id:	report_project_type_id,	// Only projects in status "active" (no substates)
            program_id:		report_program_id	// Only projects in a specific program
        },
        api: {
            read:		'/intranet-portfolio-planner/main-projects-forward-load.json',
            update:		'/intranet-portfolio-planner/main-projects-forward-load-update'
        },
        reader: {
            type:		'json',			// Tell the Proxy Reader to parse JSON
            root:		'data',			// Where do the data start in the JSON file?
            totalProperty:	'total'			// Total number of tickets for pagination
        },
        writer: {
            type:		'json', 
            rootProperty:	'data' 
        }
    }
});
