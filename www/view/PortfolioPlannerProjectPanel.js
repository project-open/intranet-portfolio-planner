/*
 * PortfolioPlannerProjectPanel.js
 *
 * Copyright (c) 2011 - 2015 ]project-open[ Business Solutions, S.L.
 * This file may be used under the terms of the GNU General Public
 * License version 3.0 or alternatively unter the terms of the ]po[
 * FL or CL license as specified in www.project-open.com/en/license.
 */

/**
 * Like a chart Series, displays a list of projects
 * using Gantt bars.
 */
Ext.define('PortfolioPlanner.view.PortfolioPlannerProjectPanel', {
    extend: 'PO.view.gantt.AbstractGanttPanel',
    requires: [
        'PO.view.gantt.AbstractGanttPanel'
    ],
    costCenterTreeResourceLoadStore: null,				// Reference to cost center store, set during init
    costCenterPanel: null,
    taskDependencyStore: null,						// Reference to cost center store, set during init
    skipGridSelectionChange: false,					// Temporaritly disable updates
    dependencyContextMenu: null,
    preferenceStore: null,
    // objectPanel: null,						// Defined in AbstractGanttPanel
    // objectStore: null,						// Defined in AbstractGanttPanel: projectResourceLoadStore

    debug: false,

    /**
     * Starts the main editor panel as the right-hand side
     * of a project grid and a cost center grid for the departments
     * of the resources used in the projects.
     */
    initComponent: function() {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.initComponent: Starting');
        this.callParent(arguments);

        // Catch the event that the object got moved
        me.on({
            'spritednd': me.onSpriteDnD,
            'spriterightclick': me.onSpriteRightClick,
            'resize': me.redraw,				// no need to redraw, correct?
            'scope': this
        });

        // Catch the moment when the "view" of the Project grid
        // is ready in order to draw the GanttBars for the first time.
        // The view seems to take a while...
        me.objectPanel.on({
            'viewready': me.onProjectGridViewReady,
            'selectionchange': me.onProjectGridSelectionChange,
            'sortchange': me.onProjectGridSortChange,
            'scope': this
        });

        // Redraw dependency arrows when loaded
        me.taskDependencyStore.on({
            'load': me.onTaskDependencyStoreChange,
            'scope': this
        });

        // Listen to vertical scroll events 
        var view = me.objectPanel.getView();
        view.on('bodyscroll',this.onObjectPanelScroll, me);
	// Horizontal scrolling implemented in onViewReady because the view has to be ready first...

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.initComponent: Finished');
    },


    /**
     * The user moves the scroll bar of the treePanel.
     * Now scroll the ganttBarPanel in the same way.
     */
    onObjectPanelScroll: function(event, view) {
        var me = this;
        var view = me.objectPanel.getView();
        var scroll = view.getEl().getScroll();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onObjectPanelScroll: Scroll='+scroll.top);
        var ganttBarScrollableEl = me.getEl();						// Ext.dom.Element that enables scrolling
        ganttBarScrollableEl.setScrollTop(scroll.top);
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onObjectPanelScroll: Finished');
    },


    /**
     * The user moves the horizontal scroll bar of the costCenterPanel.
     * Now scroll the projectPanel in the same way.
     */
    onCostCenterPanelScroll: function(event, view, a, b, c, d) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onCostCenterPanelScroll: Started');

	var scrollLeft = view.scrollLeft;
        var projectPanelScrollableEl = me.getEl();					// Ext.dom.Element that enables scrolling
        projectPanelScrollableEl.setScrollLeft(scrollLeft);

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onCostCenterPanelScroll: Finished');
    },

    /**
     * The list of projects is (finally...) ready to be displayed.
     * We need to wait until this one-time event in in order to
     * set the width of the surface and to perform the first redraw().
     * Write the selection preferences into the SelModel.
     */
    onProjectGridViewReady: function() {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectGridViewReady: Starting');

	// Listen to horizontal scroll events
        var el = me.costCenterPanel.getEl();
        if (el) {
	    el.on('scroll',me.onCostCenterPanelScroll, me);
	}

	// Check if at least one project was selected.
	// Otherwise just select all project. 
	// Otherwise people wonder why there is nothing displayed at all.
        var selModel = me.objectPanel.getSelectionModel();
        var atLeastOneProjectSelected = false
        me.objectStore.each(function(model) {
            var projectId = model.get('project_id');
            var sel = me.preferenceStore.getPreferenceBoolean('project_selected.' + projectId, true);
            if (sel) {
                me.skipGridSelectionChange = true;
                selModel.select(model, true);
                me.skipGridSelectionChange = false;
                atLeastOneProjectSelected = true;
            }
        });
        if (!atLeastOneProjectSelected) {
            selModel.selectAll(true);					// This will also update the preferences(??)
        }

        // Very first initial draw
        me.redraw();

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectGridViewReady: Finished');
    },

    onProjectGridSortChange: function(headerContainer, column, direction, eOpts) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectGridSortChange: Starting');
        me.redraw();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectGridSortChange: Finished');
    },

    /**
     * The user has selected or unselected a project in the ProjectGrid.
     * As a result, we need to re-calculate the simulation of how the
     * organization would handle the list of projects.
     */
    onProjectGridSelectionChange: function(selModel, models, eOpts) {
        var me = this;
        if (me.skipGridSelectionChange) { return; }
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectGridSelectionChange: Starting');

        // Loop through all projects and write selection changes into the preferenceStore
        me.objectStore.each(function(model) {
            var projectId = model.get('project_id');
            var prefSelected = me.preferenceStore.getPreferenceBoolean('project_selected.' + projectId, true);
            if (selModel.isSelected(model)) {
                model.set('projectGridSelected', 1);
                if (!prefSelected) {
                    me.preferenceStore.setPreference('project_selected.' + projectId, 'true');
                }
            } else {
                model.set('projectGridSelected', 0);
                if (prefSelected) {
                    me.preferenceStore.setPreference('project_selected.' + projectId, 'false');
                }
            }
        });

        // Reload the Cost Center Resource Load Store with the new selected/changed projects
        me.costCenterTreeResourceLoadStore.loadWithProjectData(me.objectStore, me.preferenceStore);

        me.redraw();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectGridSelectionChange: Finished');
    },

    /**
     * The user has right-clicked on a sprite.
     */
    onSpriteRightClick: function(event, sprite) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onSpriteRightClick: Starting: '+ sprite);
        if (null == sprite) { return; }							// Something went completely wrong...

        var className = sprite.model.$className;
        switch(className) {
        case 'PO.model.timesheet.TimesheetTaskDependency': 
            this.onDependencyRightClick(event, sprite);
            break;
        case 'PO.model.project.Project':
            this.onProjectRightClick(event, sprite);
            break;
        default:
            alert('Undefined model class: '+className);
        }
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onSpriteRightClick: Finished');
    },

    /**
     * The user has right-clicked on a dependency.
     */
    onDependencyRightClick: function(event, sprite) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onDependencyRightClick: Starting: '+ sprite);
        if (null == sprite) { return; }							// Something went completely wrong...
        var dependencyModel = sprite.model;

        // Menu for right-clicking a dependency arrow.
        if (!me.dependencyContextMenu) {
            me.dependencyContextMenu = Ext.create('Ext.menu.Menu', {
                id: 'dependencyContextMenu',
                style: {overflow: 'visible'},     // For the Combo popup
                items: [{
                    text: 'Delete Dependency',
                    handler: function() {
                        if (me.debug) console.log('dependencyContextMenu.deleteDependency: ');

                        me.taskDependencyStore.remove(dependencyModel);			// Remove from store
                        dependencyModel.destroy({
                            success: function() {
                                if (me.debug) console.log('Dependency destroyed');
                                me.redraw();
                            },
                            failure: function(model, operation) {
                                if (me.debug) console.log('Error destroying dependency: '+operation.request.proxy.reader.rawData.message);
                            }
                        });
                    }
                }]
            });
        }
        me.dependencyContextMenu.showAt(event.getXY());
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onDependencyRightClick: Finished');
    },

    /**
     * The user has right-clicked on a project bar
     */
    onProjectRightClick: function(event, sprite) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectRightClick: '+ sprite);
        if (null == sprite) { return; }							// Something went completely wrong...
    },


    /**
     * Deal with a Drag-and-Drop operation
     * and distinguish between the various types.
     */
    onSpriteDnD: function(fromSprite, toSprite, diffPoint) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onSpriteDnD: Starting: '+
                    fromSprite+' -> '+toSprite+', [' + diffPoint+']');

        if (null == fromSprite) { return; } // Something went completely wrong...
        if (null != toSprite && fromSprite != toSprite) {
            me.onCreateDependency(fromSprite, toSprite);				// dropped on another sprite - create dependency
        } else {
            me.onProjectMove(fromSprite, diffPoint[0]);					// Dropped on empty space or on the same bar
        }
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onSpriteDnD: Finished');
    },

    /**
     * Move the project forward or backward in time.
     * This function is called by onMouseUp as a
     * successful "drop" action of a drag-and-drop.
     */
    onProjectMove: function(projectSprite, xDiff) {
        var me = this;
        var projectModel = projectSprite.model;
        if (!projectModel) return;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectMove: Starting');

        var startTime = new Date(projectModel.get('start_date')).getTime();
        var endTime = new Date(projectModel.get('end_date')).getTime();
        var bBox = me.dndBaseSprite.getBBox();
        var diffTime = 1.0 * xDiff * (me.axisEndDate.getTime() - me.axisStartDate.getTime()) / (me.axisEndX - me.axisStartX);

        // we can't move projects by single days because of the weekend absence logic
        // so let's round to full weeks
        var oneWeekTime = 7.0 * 24 * 3600 * 1000;
        diffTime = Math.round(diffTime / oneWeekTime) * oneWeekTime;

        if (0 == diffTime) {
            Ext.Msg.alert("Move Projects by Weeks", "Projects can only be moved by full weeks, due to restrictions in the resource management subsystem.");
        }

        // Save original start- and end time in non-model variables
        if (!projectModel.orgStartTime) {
            projectModel.orgStartTime = startTime;
            projectModel.orgEndTime = endTime;
        }

        startTime = startTime + diffTime;
        endTime = endTime + diffTime;

        var startDate = new Date(startTime);
        var endDate = new Date(endTime);

        projectModel.set('start_date', startDate.toISOString().substring(0,10));
        projectModel.set('end_date', endDate.toISOString().substring(0,10));

        // Reload the Cost Center Resource Load Store with the new selected/changed projects
        me.costCenterTreeResourceLoadStore.loadWithProjectData(me.objectStore, me.preferenceStore);
        me.redraw();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onProjectMove: Finished');
    },


    /**
     * Create a task dependency between two two projects
     * This function is called by onMouseUp as a
     * successful "drop" action if the drop target is
     * another project.
     */
    onCreateDependency: function(fromSprite, toSprite) {
        var me = this;
        var fromProjectModel = fromSprite.model;
        var toProjectModel = toSprite.model;
        if (null == fromProjectModel) return;
        if (null == toProjectModel) return;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onCreateDependency: Starting: '+fromProjectModel.get('id')+' -> '+toProjectModel.get('id'));

        // The user dropped on another sprite.
        // Try connecting the two projects via a task dependency
        var fromProjectId = fromProjectModel.get('project_id');			// String value!
        if (null == fromProjectId) { return; }					// Something went wrong...
        var toProjectId = toProjectModel.get('project_id');			// String value!
        if (null == toProjectId) { return; }					// Something went wrong...

        // Create the stores if necessary
        if (!me.dependencyFromTaskTreeStore) {
            me.dependencyFromTaskTreeStore = Ext.create('PO.store.timesheet.TaskTreeStore', {autoSync: false, writer: false});
            me.dependencyToTaskTreeStore = Ext.create('PO.store.timesheet.TaskTreeStore', {autoSync: false, writer: false});
        }

        // Load the two main projects into the tree stores
        me.dependencyFromTaskTreeStore.getProxy().extraParams = { project_id: fromProjectId };
        me.dependencyFromTaskTreeStore.load();
        me.dependencyToTaskTreeStore.getProxy().extraParams = { project_id: toProjectId };
        me.dependencyToTaskTreeStore.load();

        if (!me.dependencyFromProjectTree) {
            me.dependencyFromProjectTree = Ext.create('Ext.tree.Panel', {
                title:				false,
                width:				290,
                height:				300,
                region:				'west',
                useArrows:			true,
                rootVisible:			false,
                store:				me.dependencyFromTaskTreeStore,
                columns: [{xtype: 'treecolumn', text: 'Create Dependency From:', flex: 2, dataIndex: 'project_name'}]
            });

            me.dependencyToProjectTree = Ext.create('Ext.tree.Panel', {
                title:				false,
                width:				290,
                height:				300,
                region:				'east',
                useArrows:			true,
                rootVisible:			false,
                store:				me.dependencyToTaskTreeStore,
                columns: [{xtype: 'treecolumn', text: 'Create Dependency To:', flex: 2, dataIndex: 'project_name'}]
            });
        }

        /**
         * Create a pop-up window showing the two
         * project trees, allowing to create a task-to-task
         * dependency link.
         */
        if (!me.dependencyPopupWindow) {
            me.dependencyPopupWindow = Ext.create('Ext.window.Window', {
                title: 'Create a dependency between two projects',
                modal: true,					// Should we mask everything behind the window?
                width: 600,
                height: 400,
                layout: 'border',
                items: [
                    me.dependencyFromProjectTree,
                    me.dependencyToProjectTree,
                    {
                        xtype: 'button',
                        text: 'Create Dependency',
                        region: 'south',
                        handler: function() {
                            if (me.debug) console.log('PO.view.gantt.AbstractGanttPanel.CreateDependency');
                            var fromSelModel = me.dependencyFromProjectTree.getSelectionModel();
                            var toSelModel = me.dependencyToProjectTree.getSelectionModel();
                            
                            var fromModel = fromSelModel.getSelection()[0];
                            var toModel = toSelModel.getSelection()[0];
                            if (null == fromModel || null == toModel) { return; }
                            
                            var fromTaskId = fromModel.get('id');
                            var toTaskId = toModel.get('id');
                            if (me.debug) console.log('PO.view.gantt.AbstractGanttPanel.createDependency: '+fromTaskId+' -> '+toTaskId);
                            
                            // Create a new dependency object
                            var dependency = new Ext.create('PO.model.timesheet.TimesheetTaskDependency', {
                                task_id_one: fromTaskId,
                                task_id_two: toTaskId
                            });
                            dependency.save({
                                success: function(depModel, operation) {
                                    if (me.debug) console.log('PO.view.gantt.AbstractGanttPanel.createDependency: successfully created dependency');
                                    
                                    // Reload the store, because the store gets extra information from the data-source
                                    me.taskDependencyStore.reload({
                                	callback: function(records, operation, result) {
                                	    if (me.debug) console.log('taskDependencyStore.reload');
                                	    me.redraw();
                                	}
                                    });
                                },
                                failure: function(depModel, operation) {
                                    var message = operation.request.scope.reader.jsonData.message;
                                    Ext.Msg.alert('Error creating dependency', message);
                                }
                            });

                            // Hide the modal window independen on success or failure
                            me.dependencyPopupWindow.hide();
                        }
                    }
                ]
            });
        }

        me.dependencyPopupWindow.show(true);
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onCreateDependency: Finished');
    },

    /**
     * Draw all Gantt bars
     */
    redraw: function() {
        var me = this;
        if (undefined === me.surface) { return; }
        me.needsRedraw = false;							// mark the "dirty" flat as cleaned
        var now = new Date();

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.redraw: Starting');

        // The Y size of the surface depends on the number of projects in the grid at the left
        var numNodes = me.objectStore.count();
        var lastProject = me.objectStore.getAt(numNodes - 1);
        var lastProjectY = me.calcGanttBarYPosition(lastProject);
        if (0 == lastProjectY) { return; }					// Project view not ready yet
        var surfaceYSize = lastProjectY + 50 + 2000;				// numNodes * 20;

        me.surface.removeAll();
        me.surface.setSize(me.axisEndX, surfaceYSize);				// Set the size of the drawing area
        // me.surface.setSize(me.axisEndX, me.surface.height);			// Set the size of the drawing area

        console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.redraw: surfaceYSize='+surfaceYSize);


        me.drawAxisAuto();							// Draw the top axis

        // Draw project bars
        var objectPanelView = me.objectPanel.getView();			// The "view" for the GridPanel, containing HTML elements
        var projectSelModel = me.objectPanel.getSelectionModel();       // ToDo: Replace SelModel with preferences(??)
        me.objectStore.each(function(model) {
            var viewNode = objectPanelView.getNode(model);		// DIV with project name on the ProjectGrid for Y coo
            if (viewNode == null) { return; }				// hidden nodes/models don't have a viewNode
            if (!projectSelModel.isSelected(model)) {
                return;
            }
            me.drawProjectBar(model);
        });

        // Draw the dependency arrows between the Gantt bars
        if (me.preferenceStore.getPreferenceBoolean('show_project_dependencies', true)) {
            me.taskDependencyStore.each(function(depModel) {
                me.drawTaskDependency(depModel);
            });
        }

        var time = new Date().getTime() - now.getTime();
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.redraw: Finished: time='+time+', items='+me.surface.items.length);
    },

    /**
     * Draw a single bar for a project or task
     */
    drawTaskDependency: function(dependencyModel) {
        var me = this;
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.drawTaskDependency: Starting: '+dependencyModel.get('id'));
        var me = this;
        var surface = me.surface;

        var taskOneId = dependencyModel.get('task_id_one');			// string!
        var taskTwoId = dependencyModel.get('task_id_two');			// string!
        var mainProjectOneId = dependencyModel.get('main_project_id_one');	// string!
        var mainProjectTwoId = dependencyModel.get('main_project_id_two');	// string!
        var s = 5;	       							// Arrow head size

        // Search for the Gantt bars corresponding to the main projects
        var items = me.surface.items.items;
        var mainProjectBarOne = null;
        var mainProjectBarTwo = null;
        for (var i = 0, ln = items.length; i < ln; i++) {
            var sprite = items[i];
            if (!sprite) continue;
            if (!sprite.model) continue;					// Only check for sprites with a (project) model

            if (sprite.model.get('id') == mainProjectOneId) { mainProjectBarOne = sprite; }
            if (sprite.model.get('id') == mainProjectTwoId) { mainProjectBarTwo = sprite; }
        }

        if (null == mainProjectBarOne || null == mainProjectBarTwo) {
            if (me.debug) console.log('Task Dependencies' + 'Did not find sprite for main_project_id');
            return;
        }

        // Get the Y coordinates from the bounding boxes
        var fromBBox = mainProjectBarOne.getBBox();
        var toBBox = mainProjectBarTwo.getBBox();
        var startY = fromBBox.y;
        var endY = toBBox.y

        // Get the X coordinates from the start- and end dates of the linked tasks
        var fromTaskEndDate = new Date(dependencyModel.get('task_one_end_date').substring(0,10));
        var toTaskStartDate = new Date(dependencyModel.get('task_two_start_date').substring(0,10));

        // Check if projects have been moved
        var mainProjectModelOne = mainProjectBarOne.model;
        var mainProjectModelTwo = mainProjectBarTwo.model;
        if (null == mainProjectBarOne || null == mainProjectBarTwo) {
            Ext.Msg.alert('Task Dependencies', 'Found null model');
            return;
        }

        // Move the start and end date of the _tasks_, according to the shift of the main project
        if (mainProjectModelOne.orgStartTime) {
            var mainProjectOneDiff = new Date(mainProjectModelOne.get('start_date').substring(0,10)).getTime() - mainProjectModelOne.orgStartTime;
            var fromTaskEndDate = new Date(fromTaskEndDate.getTime() + mainProjectOneDiff);
        }
        if (mainProjectModelTwo.orgStartTime) {
            var mainProjectTwoDiff = new Date(mainProjectModelTwo.get('start_date').substring(0,10)).getTime() - mainProjectModelTwo.orgStartTime;
            var toTaskStartDate = new Date(toTaskStartDate.getTime() + mainProjectTwoDiff);
        }

        var startX = me.date2x(fromTaskEndDate);
        var endX = me.date2x(toTaskStartDate);

        // Set the vertical start point to Correct the start/end Y position
        // and the direction of the arrow head
        var sDirected = null;
        if (endY > startY) {
            startY = fromBBox.y + fromBBox.height;
            sDirected = -s;						// Draw "normal" arrowhead pointing downwards
        } else {
            endY = toBBox.y + toBBox.height;
            sDirected = +s;						// Draw arrowhead pointing upward
        }

        // Color: Arrows are black if dependencies are OK, or red otherwise
        var color = '#222';
        if (endX < startX) { color = 'red'; }

        // Draw the arrow head (filled)
        var arrowHead = me.surface.add({
            type: 'path',
            stroke: color,
            fill: color,
            'stroke-width': 0.5,
            path: 'M '+ (endX)   + ',' + (endY)				// point of arrow head
                + 'L '+ (endX-s) + ',' + (endY + sDirected)
                + 'L '+ (endX+s) + ',' + (endY + sDirected)
                + 'L '+ (endX)   + ',' + (endY)
        }).show(true);
        arrowHead.model = dependencyModel;

        // Draw the main connection line between start and end.
        var arrowLine = me.surface.add({
            type: 'path',
            stroke: color,
            'shape-rendering': 'crispy-edges',
            'stroke-width': 0.5,
            path: 'M '+ (startX) + ',' + (startY)
                + 'L '+ (startX) + ',' + (startY - sDirected)
                + 'L '+ (endX)   + ',' + (endY + sDirected * 2)
                + 'L '+ (endX)   + ',' + (endY + sDirected)
        }).show(true);
        arrowLine.model = dependencyModel;

        // Add a tool tip to the dependency
        var html = "<b>Project Dependency</b>:<br>" +
            "From task <a href='/intranet/projects/view?project_id=" + dependencyModel.get('task_id_one') + "' target='_blank'>" + dependencyModel.get('task_one_name') + "</a> of " +
            "project <a href='/intranet/projects/view?project_id=" + dependencyModel.get('main_project_id_one') + "' target='_blank'>" + dependencyModel.get('main_project_name_one') + "</a> to " +
            "task <a href='/intranet/projects/view?project_id=" + dependencyModel.get('task_id_two') + "' target='_blank'>" + dependencyModel.get('task_two_name') + "</a> of " +
            "project <a href='/intranet/projects/view?project_id=" + dependencyModel.get('main_project_id_two') + "' target='_blank'>" + dependencyModel.get('main_project_name_two') + "</a>";
        var tip1 = Ext.create("Ext.tip.ToolTip", { target: arrowHead.el, width: 250, html: html, hideDelay: 1000 }); // give 1 second to click on project link
        var tip2 = Ext.create("Ext.tip.ToolTip", { target: arrowLine.el, width: 250, html: html, hideDelay: 1000 });
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.drawTaskDependency: Finished');
    },

    /**
     * Draw a single bar for a project or task
     */
    drawProjectBar: function(project) {
        var me = this;
        var surface = me.surface;
        var project_name = project.get('project_name');
        var start_date = project.get('start_date').substring(0,10);
        var end_date = project.get('end_date').substring(0,10);
        var startTime = new Date(start_date).getTime();
        var endTime = new Date(end_date).getTime() + 1000.0 * 3600 * 24;	// plus one day

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.drawProjectBar: project_name='+project_name+', start_date='+start_date+", end_date="+end_date);

        // Calculate the other coordinates
        var x = me.date2x(startTime);
        var y = me.calcGanttBarYPosition(project);
        var w = Math.floor(me.axisEndX * (endTime - startTime) / (me.axisEndDate.getTime() - me.axisStartDate.getTime()));
        var h = me.ganttBarHeight;						// Height of the bars
        var d = Math.floor(h / 2.0) + 1;					// Size of the indent of the super-project bar

        var spriteBar = surface.add({
            type: 'rect', x: x, y: y, width: w, height: h, radius: 3,
            fill: 'url(#gradientId)',
            stroke: 'blue',
            'stroke-width': 0.3,
            listeners: {							// Highlight the sprite on mouse-over
                mouseover: function() { this.animate({duration: 500, to: {'stroke-width': 0.5}}); },
                mouseout: function()  { this.animate({duration: 500, to: {'stroke-width': 0.3}}); }
            }
        }).show(true);

        // ToDo: remove, obsolete(?)
        spriteBar.model = project;						// Store the task information for the sprite

        
        spriteBar.dndConfig = {							// Drag-and-drop configuration
            model: project,							// Store the task information for the sprite
            baseSprite: spriteBar,						// "Base" sprite for the DnD action
            dragAction: function(panel, e, diff, dndConfig) {			// Executed onMouseMove in AbstractGanttPanel
                var shadow = panel.dndShadowSprite;				// Sprite "shadow" (copy of baseSprite) to move around
                shadow.setAttributes({translate: {x: diff[0], y: 0}}, true);	// Move shadow according to mouse position
            },
            dropAction: function(panel, e, diff, dndConfig) {			// Executed onMouseUp in AbastractGanttPanel
                if (me.debug) console.log('PortfolioPlanner.view.PortfolioPlannerProjectPanel.drawProjectBar.spriteBar.dropAction:');
                var point = me.getMousePoint(e);				// Corrected mouse coordinates
                var baseSprite = panel.dndBaseSprite;				// spriteBar to be affected by DnD
                if (!baseSprite) { return; }					// Something went completely wrong...
                var dropSprite = panel.getSpriteForPoint(point);		// Check where the user has dropped the shadow
                if (baseSprite == dropSprite) { dropSprite = null; }		// Dropped on same sprite? => normal drop
                if (0 == Math.abs(diff[0]) + Math.abs(diff[1])) {  		// Same point as before?
                    return;							// Drag-start == drag-end or single-click
                }
                if (null != dropSprite) {
                    me.onCreateDependency(baseSprite, dropSprite);		// Dropped on another sprite - create dependency
                } else {
                    me.onProjectMove(baseSprite, diff[0]);			// Dropped on empty space or on the same bar
                }
            }
        };

        // Draw availability percentage
        if (me.preferenceStore.getPreferenceBoolean('show_project_resource_load', true)) {
            var assignedDays = project.get('assigned_days');
            var colorConf = 'blue';
            var template = new Ext.Template("<div><b>Project Assignment</b>:<br>There are {value} resources assigned to project '{project_name}' and it's subprojects between {startDate} and {endDate}.<br></div>");
            me.graphOnGanttBar(spriteBar, project, assignedDays, null, new Date(startTime), colorConf, template);
        }

        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.drawProjectBar: Finished');
    },

    onTaskDependencyStoreChange: function() {
        if (me.debug) console.log('PO.view.portfolio_planner.PortfolioPlannerProjectPanel.onTaskDependencyStoreChange: Starting/Finished');
    }

});
