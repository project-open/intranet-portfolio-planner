<!-- <div id="portfolio_planner_div" style="overflow: hidden; position:absolute; width:100%; height:100%; bgcolo=red; -webkit-user-select: none; -moz-user-select: none; -khtml-user-select: none; -ms-user-select: none;"></div> -->

<div id="portfolio_planner_div" style="overflow: hidden; -webkit-user-select: none; -moz-user-select: none; -khtml-user-select: none; -ms-user-select: none; ">


<script>

var report_granularity = '@report_granularity@';
var report_start_date = '@report_start_date@'.substring(0,10);
var report_end_date = '@report_end_date@'.substring(0,10);
var report_project_type_id = '@report_project_type_id@';
var report_program_id = '@report_program_id@';

Ext.Loader.setPath('PO', '/sencha-core');
Ext.Loader.setPath('PortfolioPlanner', '/intranet-portfolio-planner/');

Ext.require([
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.tree.*',
    'PO.Utilities',
    'PO.view.gantt.AbstractGanttPanel',
    'PO.controller.ResizeController',
    'PO.controller.StoreLoadCoordinator',
    'PO.model.timesheet.TimesheetTaskDependency',
    'PO.model.finance.CostCenter',
    'PO.model.project.Project',
    'PO.store.user.SenchaPreferenceStore',
    'PO.store.timesheet.TimesheetTaskDependencyStore',
    'PortfolioPlanner.controller.SplitPanelController',
    'PortfolioPlanner.controller.ButtonController',
    'PortfolioPlanner.store.ProjectResourceLoadStore',
    'PortfolioPlanner.store.CostCenterTreeResourceLoadStore',
    'PortfolioPlanner.view.PortfolioPlannerProjectPanel',
    'PortfolioPlanner.view.PortfolioPlannerCostCenterPanel',
    'PortfolioPlanner.view.PortfolioPlannerCostCenterTree',
    'PO.view.menu.AlphaMenu',
    'PO.view.menu.ConfigMenu',
    'PO.view.menu.HelpMenu'
]);

/**
 * Create the four panels and handle external resizing events
 */
function launchApplication(debug){

    // Reference the various stores already loaded
    var projectResourceLoadStore = Ext.StoreManager.get('projectResourceLoadStore');
    var costCenterTreeResourceLoadStore = Ext.StoreManager.get('costCenterTreeResourceLoadStore');
    var senchaPreferenceStore = Ext.StoreManager.get('senchaPreferenceStore');
    var timesheetTaskDependencyStore = Ext.StoreManager.get('timesheetTaskDependencyStore');
    var issueStore = Ext.StoreManager.get('issueStore');

    // Parameters
    var renderDiv = Ext.get('portfolio_planner_div');
    var numProjects = projectResourceLoadStore.getCount();
    var gridWidth = 350;
    var projectCellHeight = 27;    // Height of grids and Gantt Panels
    var costCenterCellHeight = 39;
    var listProjectsAddOnHeight = 11;
    var listCostCenterAddOnHeight = 11;
    var gifPath = "/intranet/images/navbar_default/";
    var linkImageSrc = gifPath+'link.png';

    var reportStartDate = PO.Utilities.pgToDate('@report_start_date@');
    var reportEndDate = PO.Utilities.pgToDate('@report_end_date@');

    /* ***********************************************************************
     * Project Grid with project fields
     *********************************************************************** */
    var projectGridSelectionModel = Ext.create('Ext.selection.CheckboxModel');

    var projectGrid = Ext.create('Ext.grid.Panel', {
        title: false,
        region: 'west',
        width: gridWidth,
        store: 'projectResourceLoadStore',
        columns: [
            { sortOrder:  0, text: 'OK',		dataIndex: 'on_track_status_name',	align: 'left',	width: 50,
            renderer: function(value) {
                var valueTrim = value.trim().toLowerCase();
                switch (valueTrim) {
                case 'green':
                case 'yellow':
                case 'red':
                    return '<img src="/intranet/images/navbar_default/bb_'+valueTrim+'.gif"/>';
                    break;
                case '':
                    return '<img src="/intranet/images/navbar_default/bb_clear.gif"/>';
                    break;
                default:
                    return value;
                    break;
                }
            }},
            { sortOrder:  1, text: 'Projects',		dataIndex: 'project_name',		align: 'left',	width: 120 },
            { sortOrder:  2, text: 'Link',
              xtype: 'actioncolumn',
              dataIndex: 'project_url',
              width: 50,
              items: [{
                  icon: '/intranet/images/external.png',
                  tooltip: 'Link',
                  handler: function(grid, rowIndex, colIndex) {
                      var rec = grid.getStore().getAt(rowIndex);
                      var url = '/intranet/projects/view?project_id='+rec.get('project_id');
                      window.open(url);                       // Open project in new browser tab
                  }
              }]
            },
            { sortOrder:  3, text: 'Start',		dataIndex: 'start_date',		align: 'left',	width: 40 },
            { sortOrder:  4, text: 'End',		dataIndex: 'end_date',			align: 'left',	width: 40 },
            { sortOrder:  5, text: 'Prio',		dataIndex: 'project_priority_name',	align: 'left',	width: 40 },
            { sortOrder:  6, text: 'Done%',		dataIndex: 'percent_completed',		align: 'right',	width: 40 },
            { sortOrder:  7, text: 'On Track',		dataIndex: 'on_track_status_name',	align: 'left',	width: 40 },
            { sortOrder:  8, text: 'Budget',		dataIndex: 'project_budget',		align: 'right',	width: 40 },
            { sortOrder:  9, text: 'Budget Hours',	dataIndex: 'project_budget_hours',	align: 'right',	width: 40 },

            { sortOrder:  10, text: 'Status',		dataIndex: 'project_status',		align: 'right',	width: 40 },
            { sortOrder:  11, text: 'Type',		dataIndex: 'project_type',		align: 'right',	width: 40 },

            { sortOrder: 20, text: 'Assigned Resources',dataIndex: 'assigned_resources_planned',align: 'right',width: 40 },
            { sortOrder: 21, text: 'Invoices Actual',	dataIndex: 'cost_invoices_cache',	align: 'right',	width: 40 },
            { sortOrder: 22, text: 'Quotes Actual',	dataIndex: 'cost_quotes_cache',		align: 'right',	width: 40 },
            { sortOrder: 23, text: 'Provider Actual',	dataIndex: 'cost_bills_cache',		align: 'right',	width: 40 },
            { sortOrder: 24, text: 'POs Actual',	dataIndex: 'cost_purchase_orders_cache',align: 'right',	width: 40 },
            { sortOrder: 25, text: 'Expenses Actual',	dataIndex: 'cost_expense_logged_cache',	align: 'right',	width: 40 },
            { sortOrder: 26, text: 'Expenses Planned',	dataIndex: 'cost_expense_planned_cache',align: 'right',	width: 40 },
            { sortOrder: 27, text: 'TimeSh. Actual',	dataIndex: 'cost_timesheet_logged_cache',align: 'right', width: 40 },
            { sortOrder: 28, text: 'TimeSh. Planned',	dataIndex: 'cost_timesheet_planned_cache',align: 'right', width: 40 },
            { sortOrder: 29, text: 'Hours Actual',	dataIndex: 'reported_hours_cache',	align: 'right',	width: 40 }
        ],

        // autoScroll: true,
        overflowX: 'scroll',                            // Allows for horizontal scrolling, but not vertical
        scrollFlags: {x: true},

        selModel: projectGridSelectionModel,
        shrinkWrap: true,
        stateful: true,
        stateId: 'projectGridPanel'
    });

     // Grid with department information below the project grid
    var costCenterTree = Ext.create('PortfolioPlanner.view.PortfolioPlannerCostCenterTree', {
        debug: debug,

        width: gridWidth,
        region: 'west',
        store: 'costCenterTreeResourceLoadStore',
        autoScroll: true,
        overflowX: 'scroll',
        overflowY: false
    });
    

    // Cost Center Panel
    var portfolioPlannerCostCenterPanel = Ext.create('PortfolioPlanner.view.PortfolioPlannerCostCenterPanel', {
        debug: debug,

        title: false,
        region: 'center',
        viewBox: false,
        dndEnabled: false,				// Disable drag-and-drop for cost centers
        granularity: '@report_granularity@',
        overflowX: 'scroll',				// Allows for horizontal scrolling, but not vertical
        scrollFlags: {x: true},

        axisStartDate: reportStartDate,
        axisEndDate: reportEndDate,
        axisEndX: 2000,

        // Reference to other components
        objectStore: costCenterTreeResourceLoadStore,
        objectPanel: costCenterTree,

	projectPanel: null,
        preferenceStore: senchaPreferenceStore,

        cls: 'extjs-panel'
    });
 
    // Project Panel 
    var portfolioPlannerProjectPanel = Ext.create('PortfolioPlanner.view.PortfolioPlannerProjectPanel', {
        debug: debug,

        title: false,
        region: 'center',
        viewBox: false,
        granularity: '@report_granularity@',
        overflowX: 'scroll',						// Allows for horizontal scrolling, but not vertical
        scrollFlags: {x: true},

        axisStartDate: reportStartDate,
        axisEndDate: reportEndDate,
        axisEndX: 2000,

        // Reference to other components
        objectStore: projectResourceLoadStore,
        objectPanel: projectGrid,

        preferenceStore: senchaPreferenceStore,
        taskDependencyStore: timesheetTaskDependencyStore,
        projectResourceLoadStore: projectResourceLoadStore,
        costCenterTreeResourceLoadStore: costCenterTreeResourceLoadStore,
	costCenterPanel: portfolioPlannerCostCenterPanel,

        gradients: [
            {id:'gradientId', angle:66, stops:{0:{color:'#cdf'}, 100:{color:'#ace'}}},
            {id:'gradientId2', angle:0, stops:{0:{color:'#590'}, 20:{color:'#599'}, 100:{color:'#ddd'}}}
        ],
	cls: 'extjs-panel'
    });

    // "Backpatch" the CC panel
    portfolioPlannerCostCenterPanel.projectPanel = portfolioPlannerProjectPanel;


    /* ***********************************************************************
     * Help Menu
     *********************************************************************** */
    var helpMenu = Ext.create('Ext.menu.Menu', {
        id: 'helpMenu',
        style: {overflow: 'visible'},     // For the Combo popup
        items: [{
            text: 'Portfolio Editor Home',
            href: 'http://www.project-open.com/en/page-intranet-portfolio-planner-index',
            hrefTarget: '_blank'
        }, '-', {
            text: 'Configuration',
            href: 'http://www.project-open.com/en/page-intranet-portfolio-planner-index#configuration',
            hrefTarget: '_blank'
        }, {
            text: 'Project Dependencies',
            href: 'http://www.project-open.com/en/page-intranet-portfolio-planner-index#dependencies',
            hrefTarget: '_blank'
        }, {
            text: 'Column Configuration',
            href: 'http://www.project-open.com/en/page-intranet-portfolio-planner-index#column_configuration',
            hrefTarget: '_blank'
        }]
    });
  

    /* ***********************************************************************
     * Alpha Menu
     *********************************************************************** */
    var alphaMenu = Ext.create('PO.view.menu.AlphaMenu', {
        id: 'alphaMenu',
        alphaComponent: 'Portfolio Planner',
        slaId: 1594566,					                	// ID of the ]po[ "PD Portfolio Planner" project
        ticketStatusId: 30000				                	// "Open" and sub-states
    });


    /* ***********************************************************************
     * Config Menu
     *********************************************************************** */
    var configMenu = Ext.create('PO.view.menu.ConfigMenu', {
        debug: debug,
        id: 'configMenu',
	senchaPreferenceStore: senchaPreferenceStore,
        items: [{
	    id: 'config_menu_show_project_dependencies', 
	    key: 'show_project_dependencies', 
            text: 'Show Project Dependencies', 
            checked: true
	}, {
	    id: 'config_menu_show_project_resource_load', 
	    key: 'show_project_resource_load', 
            text: 'Show Project Assigned Resources', 
            checked: true
	}
/*	{
	    id: 'config_menu_show_dept_assigned_resources', 
	    key: 'show_dept_assigned_resources', 
            text: 'Show Department Assigned Resources', 
            checked: true
	}, {
	    id: 'config_menu_show_dept_available_resources', 
	    key: 'show_dept_available_resources', 
            text: 'Show Department Available Resources', 
            checked: false
	}, {
	    id: 'config_menu_show_dept_percent_work_load', 
	    key: 'show_dept_percent_work_load', 
            text: 'Show Department % Work Load', 
            checked: true
	}, {
	    id: 'config_menu_show_dept_accumulated_overload', 
	    key: 'show_dept_accumulated_overload', 
            text: 'Show Department Accumulated Overload', 
            checked: false
	} */
        ]
    });

    /* ***********************************************************************
     * Issue Menu
     *********************************************************************** */
    var issueMenu = Ext.create('Ext.menu.Menu', {
        id: 'issueMenu',
        style: {overflow: 'visible'},     // For the Combo popup
        items: [{
            text: '<b>Project Managers who still need to acknowledge the last project update</b>',
            href: 'http://www.project-open.com/en/page-intranet-portfolio-planner-index#issues',
            hrefTarget: '_blank'
        },'-']
    });
    issueStore.each(function(model) {
        var id = model.get('case_id');
        var item = issueMenu.items.get(id);
        if (item == null) {
            item = Ext.create('Ext.menu.Item', {
                id: id,
                href: '/intranet/projects/view?project_id='+model.get('project_id'),
                hrefTarget: '_blank',
                text: model.get('project_name')+': '+model.get('user_name')
            });
            issueMenu.add(item);
        } else {
            item.setText(item.text + ', ' + model.get('user_name'));
        }
    });



    /* ***********************************************************************
     * Main Panel that contains the three other panels
     * (projects, departments and gantt bars)
     *********************************************************************** */
    var buttonBar = Ext.create('Ext.toolbar.Toolbar', {
        dock: 'top',
        'portfolioPlannerProjectPanel': portfolioPlannerProjectPanel,
        items: [
            {id: 'buttonSave',		icon: gifPath+'disk.png',	text: 'Save', tooltip: 'Save the project to the ]po[ back-end', disabled: false}, 
            {id: 'buttonReload',	icon: gifPath+'arrow_refresh.png', text: 'Reload', tooltip: 'Reload data, discarding changes'}, 
            {id: 'buttonMinimize',	icon: gifPath+'arrow_in.png',	text: 'Minimize', tooltip: 'Restore default editor size &nbsp;', hidden: true}, 
            {id: 'buttonMaximize',	icon: gifPath+'arrow_out.png',	text: 'Maximize', tooltip: 'Maximize the editor &nbsp;' }, 
            '->', 
            {id: 'buttonZoomIn',	icon: gifPath+'zoom_in.png',	text: 'Zoom in', tooltip: 'Zoom in time axis', hidden: false}, 
            {id: 'buttonZoomOut', 	icon: gifPath+'zoom_out.png',	text: 'Zoom out', tooltip: 'Zoom out of time axis', hidden: false}, 
            '->', 
            {text: 'Configuration',	icon: gifPath+'cog.png',	menu: configMenu}, 
            {text: 'Help',		icon: gifPath+'help.png',	menu: helpMenu}, 
            {text: 'This is Beta!',	icon: gifPath+'bug.png',	menu: alphaMenu}
        ]
    });
    // add a list of issues at the right hand side only if there were issues
    if (issueStore.count() > 0) { buttonBar.insert(4, {text: 'Issues', icon: gifPath+'error.png', menu: issueMenu }); };



    var portfolioPlannerOuterPanel = Ext.create('Ext.panel.Panel', {
        title: false,
        layout: 'border',
        resizable: true,						// Allow the user to resize the outer diagram borders
        defaults: {
            collapsible: false,
            split: true,
            bodyPadding: 0
        },
        items: [{
            title: false,
            region: 'north',
            height: "50%",
            xtype: 'panel',
            layout: 'border',
            shrinkWrap: true,
            defaults: { split: true },
            items: [
                projectGrid,
                portfolioPlannerProjectPanel
            ]
        }, {
            title: false,
            region: 'center',
            height: "50%",
            xtype: 'panel',
            layout: 'border',
            shrinkWrap: true,
            defaults: { split: true },
            items: [
                costCenterTree,
                portfolioPlannerCostCenterPanel
            ]
        }],
        dockedItems: [buttonBar],
        renderTo: renderDiv
    });

    /**
     * Use resize events from the project and cost center grids 
     * to make sure both have the same size
     */
    var splitPanelController = Ext.create('PortfolioPlanner.controller.SplitPanelController', {
	debug: debug,
        projectGrid: projectGrid,
        costCenterTree: costCenterTree,
	projectPanel: portfolioPlannerProjectPanel,
	costCenterPanel: portfolioPlannerCostCenterPanel
    }).init();

    /**
     * Contoller to handle global resizing events
     */
    var resizeController = Ext.create('PO.controller.ResizeController', {
        debug: debug,
        'renderDiv': renderDiv,
        'outerContainer': portfolioPlannerOuterPanel
    }).init(this);
    resizeController.onResize();

    /*
     * GanttButtonController
     * This controller is only responsible for button actions
     * and configMenu redraws
     */
    var buttonController = Ext.create('PortfolioPlanner.controller.ButtonController', {
        resizeController: resizeController,
	senchaPreferenceStore: senchaPreferenceStore,
        projectResourceLoadStore: projectResourceLoadStore,
        portfolioPlannerProjectPanel: portfolioPlannerProjectPanel,
        portfolioPlannerCostCenterPanel: portfolioPlannerCostCenterPanel
    }).init();

};


/**
 * Application Launcher
 * Only deals with loading the required
 * stores before calling launchApplication()
 */
Ext.onReady(function() {
    Ext.QuickTips.init();

    // Disable context menus, disable double-click background selection
    Ext.getDoc().on('contextmenu', function(ev) { ev.preventDefault(); });  // Disable Right-click context menu on browser background
    // Ext.getDoc().on('mousedown', function(ev) { ev.preventDefault();  });    // Disable selection on browser background after double-click

    var debug = true;

    // Deal with state
    Ext.state.Manager.setProvider(new Ext.state.CookieProvider());

    // Show splash screen while the stores are loading
    var renderDiv = Ext.get('portfolio_planner_div');
    var splashScreen = renderDiv.mask('Loading data');
    var task = new Ext.util.DelayedTask(function() {
        splashScreen.fadeOut({duration: 100, remove: true});		// fade out the body mask
        splashScreen.next().fadeOut({duration: 100, remove: true});	// fade out the message
    });

    var projectResourceLoadStore = Ext.create('PortfolioPlanner.store.ProjectResourceLoadStore');
    var costCenterTreeResourceLoadStore = Ext.create('PortfolioPlanner.store.CostCenterTreeResourceLoadStore');
    var senchaPreferenceStore = Ext.create('PO.store.user.SenchaPreferenceStore');
    var timesheetTaskDependencyStore = Ext.create('PO.store.timesheet.TimesheetTaskDependencyStore');

    // Setup the configMenu items
    var issueStore = Ext.create('Ext.data.Store', {
        storeId: 'issueStore',
        fields: ['case_id', 'project_id', 'project_name', 'workflow_key', 'transition_key', 'user_id', 'user_name', 'user_email'],
        proxy: {
            type:   'rest',
            url:    '/intranet-reporting/view?report_code=rest_portfolio_planner_updates&format=json',
            reader: { type: 'json', root: 'data' }
        }
    });
    issueStore.load();

    // Wait for both the project and cost-center store
    // before launching the application. We need the
    // Stores in order to calculate the size of the panels
    var coo = Ext.create('PO.controller.StoreLoadCoordinator', {
        debug: debug,
        launched: false,
        stores: [
            'projectResourceLoadStore',
            'senchaPreferenceStore',
            'issueStore'
        ],
        listeners: {
            load: function() {
                if (this.launched) { return; }
                // Launch the actual application.
                console.log('PO.controller.StoreLoadCoordinator: launching Application');
                this.launched = true;
                task.delay(100);					// Fade out the splash screen
                launchApplication(debug);				// launch the actual application
            }
        }
    });

    // Load the project store and THEN load the costCenter store.
    // The Gantt panels will redraw() if stores are reloaded.
    senchaPreferenceStore.load({
        callback: function() {
            projectResourceLoadStore.load({
                callback: function() {
                    console.log('PO.controller.StoreLoadCoordinator.projectResourceLoadStore: loaded');
                    
                    // Initial load of cost center loads
                    costCenterTreeResourceLoadStore.loadWithProjectData(projectResourceLoadStore, senchaPreferenceStore);

                }
            })
        }
    });

    // Load inter-project despendencies
    timesheetTaskDependencyStore.getProxy().url = '/intranet-reporting/view';
    timesheetTaskDependencyStore.getProxy().extraParams = { format: 'json', report_code: 'rest_inter_project_task_dependencies' };
    timesheetTaskDependencyStore.load();
});

</script>
