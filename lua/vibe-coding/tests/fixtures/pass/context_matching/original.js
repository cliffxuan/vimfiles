function process_user_data(data) {
    // Validate user input
    if (!data) {
        throw new Error("No data provided");
    }
    
    // Process the data
    const result = data.map(item => {
        return {
            id: item.id,
            name: item.name,
            email: item.email
        };
    });
    
    // Return processed data
    return result;
}

function process_admin_data(data) {
    // Validate admin input
    if (!data) {
        throw new Error("No data provided");
    }
    
    // Process the data
    const result = data.map(item => {
        return {
            id: item.id,
            name: item.name,
            email: item.email,
            role: item.role
        };
    });
    
    // Return processed data
    return result;
}