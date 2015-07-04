<master>
<property name="title">@page_title@</property>
<property name="main_navbar_label">@main_navbar_label@</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>
<table>
<tr><td>
    <!-- -*-user-select: none: Disable double-click selection in background -->
<div id="portfolio_planner_div" style="overflow: hidden; position:absolute; width:100%; height:100%; bgcolo=red; -webkit-user-select: none; -moz-user-select: none; -khtml-user-select: none; -ms-user-select: none;"></div>
</td></tr>
</table>
<script>

var report_granularity = '@report_granularity@';
var report_start_date = '@report_start_date@'.substring(0,10);
var report_end_date = '@report_end_date@'.substring(0,10);
var report_project_type_id = '@report_project_type_id@';
var report_program_id = '@report_program_id@';
var report_user_id = '@current_user_id@';

Ext.Loader.setPath('PO', '/sencha-core');
Ext.Loader.setPath('PortfolioPlanner', '/intranet-portfolio-planner/');

Ext.require([
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.tree.*',
    'PO.Utilities',
    'PO.Utilities',
    'PO.view.gantt.AbstractGanttPanel',
    'PO.controller.StoreLoadCoordinator',
    'PO.model.timesheet.TimesheetTaskDependency',
    'PO.model.finance.CostCenter',
    'PO.model.project.Project',
    'PO.store.user.SenchaPreferenceStore',
    'PO.store.timesheet.TimesheetTaskDependencyStore',
    'PortfolioPlanner.store.ProjectResourceLoadStore',
    'PortfolioPlanner.store.CostCenterResourceLoadStore',
    'PortfolioPlanner.view.PortfolioPlannerProjectPanel',
    'PortfolioPlanner.view.PortfolioPlannerCostCenterPanel'
]);

/**
 * Create the four panels and
 * handle external resizing events
 */
function launchApplication(debug){
    var renderDiv = Ext.get('portfolio_planner_div');
    var projectResourceLoadStore = Ext.StoreManager.get('projectResourceLoadStore');
    var costCenterResourceLoadStore = Ext.StoreManager.get('costCenterResourceLoadStore');
    var senchaPreferenceStore = Ext.StoreManager.get('senchaPreferenceStore');
    var timesheetTaskDependencyStore = Ext.StoreManager.get('timesheetTaskDependencyStore');
    var issueStore = Ext.StoreManager.get('issueStore');
    var numProjects = projectResourceLoadStore.getCount();
    var numCostCenters = costCenterResourceLoadStore.getCount();
    var numProjectsPlusCostCenters = numProjects + numCostCenters;
    var gridWidth = 350;
    var projectCellHeight = 27;    // Height of grids and Gantt Panels
    var costCenterCellHeight = 39;
    var listProjectsAddOnHeight = 11;
    var listCostCenterAddOnHeight = 11;
    var projectGridHeight = listProjectsAddOnHeight + projectCellHeight * (1 + numProjects);
    var costCenterGridHeight = listCostCenterAddOnHeight + costCenterCellHeight * (1 + numCostCenters);
    var linkImageSrc = '/intranet/images/navbar_default/link.png';

    var reportStartDate = PO.Utilities.pgToDate('@report_start_date@');
    var reportEndDate = PO.Utilities.pgToDate('@report_end_date@');

    // Dealing with state
    Ext.state.Manager.setProvider(new Ext.state.CookieProvider());

    var projectGridSelectionModel = Ext.create('Ext.selection.CheckboxModel', {checkOnly: true});
    var projectGrid = Ext.create('Ext.grid.Panel', {
        title: false,
        region: 'west',
        width: gridWidth,
        store: 'projectResourceLoadStore',
	columns: [
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
	    { sortOrder: 10, text: 'Assigned Resources',dataIndex: 'assigned_resources_planned',align: 'right',width: 40 },
	    { sortOrder: 11, text: 'Invoices Actual',	dataIndex: 'cost_invoices_cache',	align: 'right',	width: 40 },
	    { sortOrder: 12, text: 'Quotes Actual',	dataIndex: 'cost_quotes_cache',		align: 'right',	width: 40 },
	    { sortOrder: 13, text: 'Provider Actual',	dataIndex: 'cost_bills_cache',		align: 'right',	width: 40 },
	    { sortOrder: 14, text: 'POs Actual',	dataIndex: 'cost_purchase_orders_cache',align: 'right',	width: 40 },
	    { sortOrder: 15, text: 'Expenses Actual',	dataIndex: 'cost_expense_logged_cache',	align: 'right',	width: 40 },
	    { sortOrder: 16, text: 'Expenses Planned',	dataIndex: 'cost_expense_planned_cache',align: 'right',	width: 40 },
	    { sortOrder: 17, text: 'TimeSh. Actual',	dataIndex: 'cost_timesheet_logged_cache',align: 'right',	width: 40 },
	    { sortOrder: 18, text: 'TimeSh. Planned',	dataIndex: 'cost_timesheet_planned_cache',align: 'right',	width: 40 },
	    { sortOrder: 19, text: 'Hours Actual',	dataIndex: 'reported_hours_cache',	align: 'right',	width: 40 }
	],				// Set by projectGridColumnConfig below
        autoScroll: true,
        overflowX: false,
        overflowY: false,
        selModel: projectGridSelectionModel,
        shrinkWrap: true,
	stateful: true,
	stateId: 'projectGridPanel'
    });

    var costCenterGrid = Ext.create('Ext.grid.Panel', {
        title: false,
        width: gridWidth,
        region: 'west',
        store: 'costCenterResourceLoadStore',
        autoScroll: true,
        overflowX: false,
        overflowY: false,
        columns: [
	    { sortOrder: 1, text: 'Departments', dataIndex: 'cost_center_name', width: 200 },
	    { sortOrder: 2, text: 'Resources', dataIndex: 'assigned_resources', width: 70 }
	],
        shrinkWrap: true,
	stateful: true,
	stateId: 'costCenterPanel'
    });

    // Drawing area for for Gantt Bars
    var portfolioPlannerCostCenterPanel = Ext.create('PortfolioPlanner.view.PortfolioPlannerCostCenterPanel', {
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

        objectStore: costCenterResourceLoadStore,
        objectPanel: costCenterGrid,
        preferenceStore: senchaPreferenceStore
    });


    // Drawing area for for Gantt Bars
    var portfolioPlannerProjectPanel = Ext.create('PortfolioPlanner.view.PortfolioPlannerProjectPanel', {
        title: false,
        region: 'center',
        viewBox: false,

	debug: debug,
	granularity: '@report_granularity@',
        overflowX: 'scroll',						// Allows for horizontal scrolling, but not vertical
        scrollFlags: {x: true},

        axisStartDate: reportStartDate,
        axisEndDate: reportEndDate,
	axisEndX: 2000,

        // Reference to othe robjects
        objectStore: projectResourceLoadStore,
        objectPanel: projectGrid,

        preferenceStore: senchaPreferenceStore,
        taskDependencyStore: timesheetTaskDependencyStore,

        projectResourceLoadStore: projectResourceLoadStore,
        costCenterResourceLoadStore: costCenterResourceLoadStore,

        gradients: [
            {id:'gradientId', angle:66, stops:{0:{color:'#cdf'}, 100:{color:'#ace'}}},
            {id:'gradientId2', angle:0, stops:{0:{color:'#590'}, 20:{color:'#599'}, 100:{color:'#ddd'}}}
        ]
    });


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
    var betaMenu = Ext.create('Ext.menu.Menu', {
        id: 'betaMenu',
        style: {overflow: 'visible'},     // For the Combo popup
        items: [{
            text: '<b>This is Experimental and "Alpha" Software</b> - Please see known issues below',
            href: 'http://www.project-open.com/en/page-intranet-portfolio-planner-index',
            hrefTarget: '_blank'
        }, '-']
    });
    
    var issues = [
        "Bug: Show red dependency arrows if somebody disables a referenced project",
        "Ext: Show Save only if something has changed (project store)",
        "Bug: Firefox doesn't show cost centers when the ExtJS page is longer than the browser page",
        "Bug: Don't show SLAs and similar projects",
        "Ext: Exclude certain other (small) projects? How?",
        "Ext: Allow some form of left/right scrolling. Arrow in date bar?",
        "Ext: Should enable/disable change the project status? Or just notify PMs?",
        "Ext: Add Columns: Show sums",
        "Ext: Show departments hierarchy",
        "Ext: Show unassigned users",
        "Ext: Reset Configuration should also reset stored status",
        "Bug: Reset Configuration doesn't work anymore"
    ];
    for (var i = 0; i < issues.length; i++) {
        var item = Ext.create('Ext.menu.Item', {
            text: issues[i]
        });
        betaMenu.add(item);
    }

    /* ***********************************************************************
     * Config Menu
     *********************************************************************** */
    var configMenuOnItemCheck = function(item, checked){
        console.log('configMenuOnItemCheck: item.id='+item.id);
        senchaPreferenceStore.setPreference('@page_url@', item.id, checked);
        portfolioPlannerProjectPanel.redraw();
        portfolioPlannerCostCenterPanel.redraw();
    }

    var configMenu = Ext.create('Ext.menu.Menu', {
        id: 'configMenu',
        style: {overflow: 'visible'},     // For the Combo popup
        items: [{
                text: 'Reset Configuration',
                handler: function() {
                    console.log('configMenuOnResetConfiguration');
                    senchaPreferenceStore.each(function(model) {
                        var url = model.get('preference_url');
                        if (url != '@page_url@') { return; }
                        model.destroy();
                    });
		    // Reset column configuration
		    projectGridColumnConfig.each(function(model) { 
			model.destroy({
			    success: function(model) {
				console.log('configMenuOnResetConfiguration: Successfully destroyed a CC config');
				var count = projectGridColumnConfig.count() + costCenterGridColumnConfig.count();
				if (0 == count) {
				    // Reload the page. 
				    var params = Ext.urlDecode(location.search.substring(1));
				    var url = window.location.pathname + '?' + Ext.Object.toQueryString(params);
				    window.location = url;
				}
			    }
			}); 
		    });
		    costCenterGridColumnConfig.each(function(model) { 
			model.destroy({
			    success: function(model) {
				console.log('configMenuOnResetConfiguration: Successfully destroyed a CC config');
				var count = projectGridColumnConfig.count() + costCenterGridColumnConfig.count();
				if (0 == count) {
				    // Reload the page. 
				    var params = Ext.urlDecode(location.search.substring(1));
				    var url = window.location.pathname + '?' + Ext.Object.toQueryString(params);
				    window.location = url;
				}
			    }
			}); 
		    });
                }
        }, '-']
    });

    // Setup the configMenu items
    var confSetupStore = Ext.create('Ext.data.Store', {
        fields: ['key', 'text', 'def'],
        data : [
            {key: 'show_project_dependencies', text: 'Show Project Dependencies', def: true},
            {key: 'show_project_resource_load', text: 'Show Project Assigned Resources', def: true},
            {key: 'show_dept_assigned_resources', text: 'Show Department Assigned Resources', def: true},
            {key: 'show_dept_available_resources', text: 'Show Department Available Resources', def: false},
            {key: 'show_dept_percent_work_load', text: 'Show Department % Work Load', def: true},
            {key: 'show_dept_accumulated_overload', text: 'Show Department Accumulated Overload', def: false}
        ]
    });
    confSetupStore.each(function(model) {
        console.log('confSetupStore: '+model);
        var key = model.get('key');
        var def = model.get('def');
        var checked = senchaPreferenceStore.getPreferenceBoolean(key, def);
        if (!senchaPreferenceStore.existsPreference(key)) {
            senchaPreferenceStore.setPreference('@page_url@', key, checked ? 'true' : 'false');
        }
        var item = Ext.create('Ext.menu.CheckItem', {
            id: key,
            text: model.get('text'),
            checked: checked,
            checkHandler: configMenuOnItemCheck
        });
        configMenu.add(item);
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
    Ext.define('PO.view.portfolio_planner.ButtonBar', {
        extend: 'Ext.toolbar.Toolbar',
        portfolioPlannerProjectPanel: null,
        initComponent: function() {
            this.callParent(arguments);
            console.log('ButtonBar: initComponent');
        }
    });

    var buttonBar = Ext.create('PO.view.portfolio_planner.ButtonBar', {
        dock: 'top',
        portfolioPlannerProjectPanel: portfolioPlannerProjectPanel,
        items: [
            {
                text: 'Save',
                icon: '/intranet/images/navbar_default/disk.png',
                tooltip: 'Save the project to the ]po[ back-end',
                disabled: false,
                id: 'buttonSave',
                handler: function() {
                    // Save the currently modified projects
                    Ext.Msg.show({
                        title: 'Save Project Schedule?',
                        msg: 'We will inform all affected project managers <br>about the changed schedule.',
                        buttons: Ext.Msg.OKCANCEL,
                        icon: Ext.Msg.QUESTION,
                        fn: function(button, text, opt) {
                            // Save the store and launch workflows
                            if ("ok" == button) {
                                projectResourceLoadStore.save({
                                    success: function(a,b,c,d,e) {
                                        console.log('PO.view.portfolio_planner.ButtonBar: projectResourceLoadStore.save(): success');
                                        portfolioPlannerProjectPanel.redraw();
                                        portfolioPlannerCostCenterPanel.redraw();
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
                }
            }, {
                id: 'buttonZoomIn',
                text: 'Zoom in',
                icon: '/intranet/images/navbar_default/zoom_in.png',
                tooltip: 'Zoom in time axis',
                handler: function() {
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
                hidden: false
            }, {
                id: 'buttonZoomOut',
                text: 'Zoom out',
                icon: '/intranet/images/navbar_default/zoom_out.png',
                tooltip: 'Zoom out of time axis',
                handler: function() {
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
                },
                hidden: false
            }, '->', {
                text: 'Configuration',
                icon: '/intranet/images/navbar_default/cog.png',
                menu: configMenu
            }, {
                text: 'Help',
                icon: '/intranet/images/navbar_default/help.png',
                menu: helpMenu
            }, {
                text: 'This is Alpha!',
                icon: '/intranet/images/navbar_default/bug.png',
                menu: betaMenu
            }
        ]
    });
    
    // add a list of issues at the right hand side,
    // only if there were issues
    if (issueStore.count() > 0) {
        buttonBar.insert(4,{
            text: 'Issues', 
            icon: '/intranet/images/navbar_default/error.png', 
            menu: issueMenu
        });
    };

    var buttonPanelHeight = 40;
    var borderPanelHeight = buttonPanelHeight + costCenterGridHeight + projectGridHeight;
    var sideBar = Ext.get('sidebar');					// ]po[ left side bar component
    var sideBarWidth = sideBar.getSize().width;
    var borderPanelWidth = Ext.getBody().getViewSize().width - sideBarWidth - 85;
    var borderPanel = Ext.create('Ext.panel.Panel', {
        width: borderPanelWidth,
        height: borderPanelHeight,
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
            height: projectGridHeight,
            xtype: 'panel',
            layout: 'border',
            shrinkWrap: true,
            items: [
                projectGrid,
                portfolioPlannerProjectPanel
            ]
        }, {
            title: false,
            region: 'center',
            height: costCenterGridHeight,
            xtype: 'panel',
            layout: 'border',
            shrinkWrap: true,
            items: [
                costCenterGrid,
                portfolioPlannerCostCenterPanel
            ]
        }],
        dockedItems: [buttonBar],
        renderTo: renderDiv
    });

    
    var onResize = function (sideBarWidth) {
        console.log('launchApplication.onResize: Starting');
        var screenWidth = Ext.getBody().getViewSize().width;
        var width = screenWidth - sideBarWidth;
        borderPanel.setSize(width, borderPanelHeight);
        // No redraw necessary, because borderPanel initiates a redraw anyway
        console.log('launchApplication.onResize: Finished');
    };

    var onWindowResize = function () {
        console.log('launchApplication.onWindowResize: Starting');
        var sideBar = Ext.get('sidebar');				// ]po[ left side bar component
        var sideBarWidth = sideBar.getSize().width;
        if (sideBarWidth > 100) {
            sideBarWidth = 340;						// Determines size when Sidebar visible
        } else {
            sideBarWidth = 85;						// Determines size when Sidebar collapsed
        }
        onResize(sideBarWidth);
        console.log('launchApplication.onWindowResize: Finished');
    };

    // Manually changed the size of the borderPanel
    var onBorderPanelResize = function () {
        console.log('launchApplication.onBorderPanelResize: Starting');
        portfolioPlannerProjectPanel.redraw();
        portfolioPlannerCostCenterPanel.redraw();
        console.log('launchApplication.onBorderPanelResize: Finished');
    };

    var onSidebarResize = function () {
        console.log('launchApplication.onSidebarResize: Starting');
        // ]po[ Sidebar
        var sideBar = Ext.get('sidebar');				// ]po[ left side bar component
        var sideBarWidth = sideBar.getSize().width;
        // We get the event _before_ the sideBar has changed it's size.
        // So we actually need to the the oposite of the sidebar size:
        if (sideBarWidth > 100) {
            sideBarWidth = 85;						// Determines size when Sidebar collapsed
        } else {
            sideBarWidth = 340;						// Determines size when Sidebar visible
        }
        onResize(sideBarWidth);
        console.log('launchApplication.onSidebarResize: Finished');
    };

    borderPanel.on('resize', onBorderPanelResize);
    Ext.EventManager.onWindowResize(onWindowResize);
    var sideBarTab = Ext.get('sideBarTab');
    sideBarTab.on('click', onSidebarResize);

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

    // Show splash screen while the stores are loading
    var renderDiv = Ext.get('portfolio_planner_div');
    var splashScreen = renderDiv.mask('Loading data');
    var task = new Ext.util.DelayedTask(function() {
        splashScreen.fadeOut({duration: 100, remove: true});		// fade out the body mask
        splashScreen.next().fadeOut({duration: 100, remove: true});	// fade out the message
    });

    var projectResourceLoadStore = Ext.create('PortfolioPlanner.store.ProjectResourceLoadStore');
    var costCenterResourceLoadStore = Ext.create('PortfolioPlanner.store.CostCenterResourceLoadStore');
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

    // Wait for both the project and cost-center store
    // before launching the application. We need the
    // Stores in order to calculate the size of the panels
    var coo = Ext.create('PO.controller.StoreLoadCoordinator', {
        debug: 0,
        launched: false,
        stores: [
            'projectResourceLoadStore',
            'costCenterResourceLoadStore',
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
                    // Now load the cost center load
                    costCenterResourceLoadStore.loadWithProjectData(projectResourceLoadStore, senchaPreferenceStore);
                }
            })
        }
    });


    timesheetTaskDependencyStore.getProxy().url = '/intranet-reporting/view';
    timesheetTaskDependencyStore.getProxy().extraParams = { format: 'json', report_code: 'rest_inter_project_task_dependencies' };
    timesheetTaskDependencyStore.load();

    issueStore.load();

});

</script>
