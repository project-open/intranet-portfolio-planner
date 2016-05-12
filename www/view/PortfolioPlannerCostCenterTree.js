/*
 * PortfolioPlannerCostCenterTree.js
 *
 * Copyright (c) 2011 - 2014 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */


/**
 * TreePanel with the list of CostCenters in the company.
 */
Ext.define('PortfolioPlanner.view.PortfolioPlannerCostCenterTree', {
    extend:				'Ext.tree.Panel',
    alias:				'portfolioPlannerCostCenterTree',
    title:				false,
    shrinkWrap:				true,
    animate:				false,				// Animation messes up bars on the right side
    rootVisible:			false,

    // the 'columns' property is now 'headers'
    columns: [
        {text: 'Id', width: 50, dataIndex: 'id', hidden: true}, 
        {text: 'Parent', flex: 0, width: 50, dataIndex: 'parent_id', hidden: true}, 
        {text: 'Name', xtype: 'treecolumn', flex: 2, sortable: true, dataIndex: 'cost_center_name',
         renderer: function(v, context, model, d, e) {
             context.style = 'cursor: pointer;';
	     return model.get('cost_center_name'); 

         }},
        {text: 'Res %', width: 50, dataIndex: 'assigned_resources', hidden: false}

    ]
});


