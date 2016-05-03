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

    projectPanel: null,
    costCenterPanel: null,

    init: function() {
        var me = this;
        if (me.debug) { if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.init: Starting'); }

	me.projectPanel.on(
	    'resize', me.onProjectPanelResize, me
	);
	me.costCenterPanel.on(
	    'resize', me.onCostCenterPanelResize, me
	);

        if (me.debug) { if (me.debug) console.log('PortfolioPlanner.controller.SplitPanelController.init: Finished'); }
        return this;
    },

    onProjectPanelResize: function(projectPanel,width,height,oldWidth,oldHeight,eOpts) {
	var me = this;
	me.costCenterPanel.flex = null;
	me.costCenterPanel.setWidth(width);
    },

    onCostCenterPanelResize: function(costCenterPanel,width,height,oldWidth,oldHeight,eOpts) {
	var me = this;
	me.projectPanel.flex = null;
	me.projectPanel.setWidth(width);
    }
});

