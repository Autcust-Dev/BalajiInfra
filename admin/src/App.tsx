import { Navigate, Route, Routes } from 'react-router-dom'
import { ProtectedRoute } from '@/components/auth/ProtectedRoute'
import { StatusGate } from '@/components/auth/StatusGate'
import { AppShell } from '@/components/layout/AppShell'
import { LoginPage } from '@/routes/LoginPage'
import { MfaEnrollPage } from '@/routes/MfaEnrollPage'
import { MfaVerifyPage } from '@/routes/MfaVerifyPage'
import { PropertiesPage } from '@/routes/PropertiesPage'
import { PropertyRoomsPage } from '@/routes/PropertyRoomsPage'
import { TenantFormPage } from '@/routes/TenantFormPage'
import { TenantsPage } from '@/routes/TenantsPage'

function App() {
  return (
    <Routes>
      <Route
        path="/login"
        element={
          <StatusGate when="signed-out">
            <LoginPage />
          </StatusGate>
        }
      />
      <Route
        path="/mfa/enroll"
        element={
          <StatusGate when="mfa-enroll">
            <MfaEnrollPage />
          </StatusGate>
        }
      />
      <Route
        path="/mfa/verify"
        element={
          <StatusGate when="mfa-verify">
            <MfaVerifyPage />
          </StatusGate>
        }
      />

      <Route element={<ProtectedRoute />}>
        <Route element={<AppShell />}>
          <Route index element={<Navigate to="/properties" replace />} />
          <Route path="/properties" element={<PropertiesPage />} />
          <Route path="/properties/:propertyId/rooms" element={<PropertyRoomsPage />} />
          <Route path="/tenants" element={<TenantsPage />} />
          <Route path="/tenants/new" element={<TenantFormPage />} />
          <Route path="/tenants/:tenantId/edit" element={<TenantFormPage />} />
        </Route>
      </Route>
    </Routes>
  )
}

export default App
