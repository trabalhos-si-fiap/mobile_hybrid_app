import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { of } from 'rxjs';

import { AuthUser } from '../../core/models/auth.model';
import { AuthService } from '../../core/services/auth.service';
import { LoginComponent } from './login.component';

describe('LoginComponent', () => {
  let login: Mock;
  let router: Router;

  beforeEach(() => {
    login = vi.fn();
  });

  async function render(
    query: Record<string, string> = {},
  ): Promise<ComponentFixture<LoginComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { queryParamMap: convertToParamMap(query) } },
        },
        { provide: AuthService, useValue: { login } },
      ],
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigateByUrl').mockResolvedValue(true);

    const fixture = TestBed.createComponent(LoginComponent);
    await fixture.whenStable();
    return fixture;
  }

  async function submit(fixture: ComponentFixture<LoginComponent>, user: AuthUser): Promise<void> {
    login.mockReturnValue(of(user));
    fixture.componentInstance.form.setValue({
      email: user.email,
      password: 'secret',
      remember: false,
    });
    fixture.componentInstance.submit();
    await fixture.whenStable();
  }

  function text(fixture: ComponentFixture<LoginComponent>): string {
    return fixture.nativeElement.textContent;
  }

  it('blocks a USER account with the app message', async () => {
    const fixture = await render();

    await submit(fixture, { id: 50, name: 'Ana Usuária', email: 'ana@edu.com', role: 'USER' });

    expect(text(fixture)).toContain(
      'Esta conta é de cliente. Use o app Edu para abrir e acompanhar chamados.',
    );
    expect(router.navigateByUrl).not.toHaveBeenCalled();
  });

  it('sends staff to the dashboard', async () => {
    const fixture = await render();

    await submit(fixture, { id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' });

    expect(router.navigateByUrl).toHaveBeenCalledWith('/dashboard');
  });

  it('shows the expired-session notice from the URL', async () => {
    const fixture = await render({ sessao: 'expirada' });

    expect(text(fixture)).toContain('Sua sessão expirou. Entre novamente.');
  });

  it('shows no notice on a plain visit', async () => {
    const fixture = await render();

    expect(text(fixture)).not.toContain('Sua sessão expirou');
  });
});
