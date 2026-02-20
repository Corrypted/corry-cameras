let cameraListData = [];
let selectedCameraItem = null;
let isCameraUIInitialized = false;

$(document).ready(function() {
    if (isCameraUIInitialized) {
        console.log('[Camera NUI] Already initialized, skipping');
        return;
    }
    isCameraUIInitialized = true;
    
    console.log('[Camera NUI] Script loaded successfully');
    
    // Hide UI on load
    $("#camera-container").hide();

    // Listen for NUI messages
    window.addEventListener('message', handleCameraNUIMessage);

    // Close button
    $("#camera-close-btn").off('click').on('click', function() {
        console.log('[Camera NUI] Close button clicked');
        closeCameraList();
    });

    // View camera button
    $("#camera-view-btn").off('click').on('click', function() {
        console.log('[Camera NUI] View button clicked');
        if (selectedCameraItem) {
            $.post(`https://${GetParentResourceName()}/viewCamera`, JSON.stringify({
                cameraId: selectedCameraItem.id
            }));
            // Don't close the list, just hide the UI
            $("#camera-container").hide();
        }
    });

    // Add access button
    $("#camera-add-btn").off('click').on('click', function() {
        console.log('[Camera NUI] Add button clicked');
        if (selectedCameraItem) {
            toggleAddAccessDropdown();
        }
    });
    
    // Confirm add button
    $("#confirm-add-btn").off('click').on('click', function() {
        const stateId = $("#access-state-id").val().trim();
        if (!stateId) {
            return;
        }
        
        if (selectedCameraItem) {
            $.post(`https://${GetParentResourceName()}/addCameraAccess`, JSON.stringify({
                cameraId: selectedCameraItem.id,
                stateId: stateId
            }));
            
            // Clear input and hide dropdown
            $("#access-state-id").val('');
            $("#add-access-dropdown").addClass('hidden');
        }
    });
    
    // Cancel add button
    $("#cancel-add-btn").off('click').on('click', function() {
        $("#access-state-id").val('');
        $("#add-access-dropdown").addClass('hidden');
    });

    // Search functionality
    $("#camera-search").off('input').on('input', function() {
        const searchTerm = $(this).val().toLowerCase();
        console.log('[Camera NUI] Search term:', searchTerm);
        
        if (searchTerm.length > 0) {
            $("#camera-clear-search").removeClass('hidden');
        } else {
            $("#camera-clear-search").addClass('hidden');
        }
        
        filterCameraList(searchTerm);
    });

    // Clear search button
    $("#camera-clear-search").off('click').on('click', function() {
        $("#camera-search").val('');
        $(this).addClass('hidden');
        filterCameraList('');
    });

    // ESC key to close
    $(document).off('keyup').on('keyup', function(e) {
        if (e.key === "Escape" || e.key === "Esc") {
            if (!$("#camera-container").hasClass('hidden')) {
                console.log('[Camera NUI] ESC key detected, closing camera list');
                closeCameraList();
            }
        }
    });
});

function handleCameraNUIMessage(event) {
    const data = event.data;
    
    // Ignore messages without action
    if (!data || !data.action) return;
    
    console.log('[Camera NUI] Received message:', data.action);
    
    if (data.action === 'openCameraList') {
        openCameraList(data.cameras);
    } else if (data.action === 'updateCameraList') {
        updateCameraList(data.cameras);
    } else if (data.action === 'closeCameraList') {
        closeCameraList();
    } else if (data.action === 'showContainer') {
        $("#camera-container").show();
    }
}

function openCameraList(cameras) {
    console.log('[Camera NUI] openCameraList called with:', cameras.length, 'cameras');
    
    cameraListData = cameras;
    selectedCameraItem = null;

    // Update header
    $("#camera-count").text(cameras.length + " camera" + (cameras.length !== 1 ? "s" : "") + " available");

    // Hide action buttons
    hideCameraActions();

    // Clear search
    $("#camera-search").val('');
    $("#camera-clear-search").addClass('hidden');

    // Render cameras
    renderCameraList(cameras);

    // Show UI
    console.log('[Camera NUI] Showing UI');
    $("#camera-container").removeClass('hidden').fadeIn(300);
}

function updateCameraList(cameras) {
    console.log('[Camera NUI] updateCameraList called with:', cameras.length, 'cameras');
    
    cameraListData = cameras;
    selectedCameraItem = null;

    // Update count
    $("#camera-count").text(cameras.length + " camera" + (cameras.length !== 1 ? "s" : "") + " available");

    // Hide action buttons
    hideCameraActions();

    // Re-render cameras
    renderCameraList(cameras);
}

function closeCameraList() {
    console.log('[Camera NUI] closeCameraList function called');
    
    // Hide UI immediately
    $("#camera-container").css('display', 'none').addClass('hidden');
    
    // Clear camera list
    $("#camera-list").empty();
    
    // Hide action buttons
    hideCameraActions();
    
    console.log('[Camera NUI] Posting closeCameraUI callback to client');
    // Notify client
    $.post(`https://${GetParentResourceName()}/closeCameraUI`, JSON.stringify({}));
}

function renderCameraList(cameras) {
    const cameraList = $("#camera-list");
    const emptyState = $("#camera-empty-state");
    
    cameraList.empty();

    if (cameras.length === 0) {
        cameraList.hide();
        emptyState.removeClass('hidden').show();
        return;
    }

    emptyState.addClass('hidden').hide();
    cameraList.show();

    cameras.forEach(function(camera) {
        const cameraCard = createCameraCard(camera);
        cameraList.append(cameraCard);
    });
}

function createCameraCard(camera) {
    const status = camera.active ? 'active' : 'offline';
    const statusText = camera.active ? 'Active' : 'Offline';
    
    const card = $(`
        <div class="camera-card" data-camera-id="${camera.id}">
            <div class="camera-card-header">
                <div class="camera-info">
                    <h3>${camera.name || 'Camera #' + camera.id}</h3>
                    <p>${camera.location || 'Unknown Location'}</p>
                </div>
                <div class="camera-status status-${status}">${statusText}</div>
            </div>
            <div class="camera-details">
                <div class="detail-item">
                    <span class="detail-label">ID</span>
                    <span class="detail-value">#${camera.id}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Placed</span>
                    <span class="detail-value">${camera.placed || 'Unknown'}</span>
                </div>
            </div>
        </div>
    `);

    card.on('click', function() {
        selectCamera(camera, $(this));
    });

    return card;
}

function selectCamera(camera, cardElement) {
    console.log('[Camera NUI] Camera selected:', camera.id);
    
    // Remove selection from all cards
    $('.camera-card').removeClass('selected');
    
    // Add selection to clicked card
    cardElement.addClass('selected');
    
    // Store selected camera
    selectedCameraItem = camera;
    
    // Show action buttons
    showCameraActions();
}

function showCameraActions() {
    console.log('[Camera NUI] showCameraActions called');
    $("#camera-actions-container").removeClass('hidden').show();
}

function hideCameraActions() {
    $("#camera-actions-container").addClass('hidden').hide();
    $("#add-access-dropdown").addClass('hidden');
    $("#access-state-id").val('');
    selectedCameraItem = null;
    $('.camera-card').removeClass('selected');
}

function toggleAddAccessDropdown() {
    const dropdown = $("#add-access-dropdown");
    if (dropdown.hasClass('hidden')) {
        dropdown.removeClass('hidden');
        $("#access-state-id").focus();
    } else {
        dropdown.addClass('hidden');
        $("#access-state-id").val('');
    }
}

function filterCameraList(searchTerm) {
    if (!cameraListData || cameraListData.length === 0) return;
    
    const cameraList = $("#camera-list");
    const emptyState = $("#camera-empty-state");
    
    if (searchTerm === '') {
        // Show all cameras when search is cleared
        $('.camera-card').show();
        cameraList.show();
        emptyState.addClass('hidden').hide();
        return;
    }
    
    let visibleCount = 0;
    
    $('.camera-card').each(function() {
        const cameraId = $(this).data('camera-id');
        const camera = cameraListData.find(c => c.id === cameraId);
        
        if (camera) {
            const cameraName = (camera.name || '').toLowerCase();
            const cameraLocation = (camera.location || '').toLowerCase();
            const cameraIdStr = camera.id.toString();
            
            if (cameraName.includes(searchTerm) || 
                cameraLocation.includes(searchTerm) || 
                cameraIdStr.includes(searchTerm)) {
                $(this).show();
                visibleCount++;
            } else {
                $(this).hide();
            }
        }
    });
    
    // Show empty state if no results
    if (visibleCount === 0) {
        cameraList.hide();
        emptyState.removeClass('hidden').show();
        emptyState.find('h3').text('No Cameras Found');
        emptyState.find('p').text('Try adjusting your search terms');
    } else {
        cameraList.show();
        emptyState.addClass('hidden').hide();
    }
}
