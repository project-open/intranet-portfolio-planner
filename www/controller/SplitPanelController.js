/*
 * SplitPanelController.js
 *
 * Copyright (c) 2011 - 2014 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */

/**
 * SplitPanelController
 *
 * Small controller that checks resize events from the 
 * project and cost center grids and makes sure that they
 * are of the same size
 */
Ext.define('PortfolioPlanner.controller.SplitPanelController', {
    extend: 'Ext.app.Controller',
    debug: false,

    projectGrid: null,
    costCenterTree: null,
    projectPanel: null,
    costCenterPanel: null,

    init: function() {
        var me = this;
        if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.init: Starting');

        me.projectGrid.on(
            'resize', me.onProjectPanelResize, me
        );
        me.costCenterTree.on(
            'resize', me.onCostCenterPanelResize, me
        );

        if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.init: Finished');
        return this;
    },

    onProjectPanelResize: function(projectGrid,width,height,oldWidth,oldHeight,eOpts) {
        var me = this;
        if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.onProjectPanelResize: Starting');

        me.costCenterTree.flex = null;
        me.costCenterTree.setWidth(width);

	// For some reason the setWidth() above messes with the size of the surfaces of the panels.
	me.projectPanel.redraw();
	me.costCenterPanel.redraw();

        if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.onProjectPanelResize: Finished');
    },

    onCostCenterPanelResize: function(costCenterTree,width,height,oldWidth,oldHeight,eOpts) {
        var me = this;
        if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.onCostCenterPanelResize: Starting');

        me.projectGrid.flex = null;
        me.projectGrid.setWidth(width);

	// For some reason the setWidth() above messes with the size of the surfaces of the panels.
	me.projectPanel.redraw();
	me.costCenterPanel.redraw();

        if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.onCostCenterPanelResize: Finished');
    }
});

