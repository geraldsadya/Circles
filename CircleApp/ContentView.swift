import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Icon
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 2)
                    )
                    .overlay(
                        Text("C")
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    )
                
                VStack(spacing: 16) {
                    Text("Circle")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Social life, verified.")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Ready to prove it today?")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Sign in with Apple")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Button(action: {}) {
                        Text("Continue as Guest")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Circle")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
