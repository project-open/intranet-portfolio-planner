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

    ],

    initComponent: function() {
        var me = this;
        if (me.debug) console.log('PortfolioPlanner.view.PortfolioCostCenterTree.initComponent: Starting');
        this.callParent(arguments);

	// Mini-controller built-in
        me.on({
            'itemcollapse': this.onItemCollapse,
            'itemexpand': this.onItemExpand
        });

        if (me.debug) console.log('PortfolioPlanner.view.PortfolioCostCenterTree.initComponent: Finished');
    },

    onItemCollapse: function(model) {
        var me = this;
        if (me.debug) console.log('PortfolioPlanner.view.PortfolioCostCenterTree.onItemCollapse: Starting');

        // Remember the new state
        var object_id = model.get('id');
	if (isNaN(object_id)) return;
        Ext.Ajax.request({
            url: '/intranet/biz-object-tree-open-close.tcl',
            params: { 'object_id': object_id, 'open_p': 'c' }
        });

        if (me.debug) console.log('PortfolioPlanner.view.PortfolioCostCenterTree.onItemCollapse: Finished');
    },

    onItemExpand: function(model) {
        var me = this;
        if (me.debug) console.log('PortfolioPlanner.view.PortfolioCostCenterTree.onItemExpand: Starting');

        // Remember the new state
        var object_id = model.get('id');
	if (isNaN(object_id)) return;
        Ext.Ajax.request({
            url: '/intranet/biz-object-tree-open-close.tcl',
            params: { 'object_id': object_id, 'open_p': 'o' }
        });


        if (me.debug) console.log('PortfolioPlanner.view.PortfolioCostCenterTree.onItemExpand: Finished');
    }

});


